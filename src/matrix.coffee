try
  { Robot
  , Adapter
  , TextMessage } = require 'hubot'
catch
  prequire = require 'parent-require'
  { Robot
  , Adapter
  , TextMessage } = prequire 'hubot'

{ LocalStorage } = require 'node-localstorage'

sdk = require 'matrix-js-sdk'
ne  = require 'needle'
syn = require 'async'
gm  = require 'gm'
url = require 'url'


class Matrix extends Adapter
  constructor: ->
    super
    @local_storage = new LocalStorage process.env.HUBOT_MATRIX_DATA || 'matrix-data'
    @text = []


  handleUnknownDevices: (err) ->
    for stranger, devices of err.devices
      for device, _ of devices
        @robot.logger.info "Acknowledging #{stranger}'s device #{device}"
        @client.setDeviceKnown(stranger, device)


  handleURL: (envelope) -> (line, done) =>
    # supported image mime types
    accepted = ['image/jpeg', 'image/png', 'image/tiff']


    if not url.parse(line).hostname
      return @sendText envelope, line, -> done()

    # fetch headers
    ne.head line, follow_max: 5, (err, res) =>
      @robot.logger.info 'found url ' + line
      if err?
        @robot.logger.warning "headers download failed:\n#{err}"
        return @sendText envelope, line, -> done()

      mimetype = res.headers['content-type'].split(';')[0]
      if not (mimetype in accepted)
        @robot.logger.info 'url ignored'
        return @sendText envelope, line, -> done()

      @robot.logger.info 'found image: downloading...'

      @getImage line, (buffer, info) =>
        @sendImage envelope, buffer, info, -> done()


  getImage: (imageURL, callback) ->
    # process the image a bit
    ne.get imageURL, follow_max: 5, (err, res, body) =>
      gm(body)
      .noProfile()
      .quality(80)
      .resize(360000,'@>')
      .toBuffer (err, buffer) =>
        @robot.logger.info 'image downloaded and processed'

        gm(buffer).identify "%m %w %h", (err, format) ->
          [type, width, height] = format.split ' '
          callback buffer,
            mimetype: "image/" + type.toLowerCase()
            w: width
            h: height
            size: buffer.length
            url: imageURL


  sendText: (envelope, text, callback) ->
    @client.sendNotice(envelope.room.id, text).catch (err) =>
      if err.name == 'UnknownDeviceError'
        @handleUnknownDevices err
        @client.sendNotice(envelope.room.id, text)
    callback() if callback?


  sendImage: (envelope, buffer, info, callback) ->
    try
      @client.uploadContent(buffer,
        name: info.url
        type: info.mimetype
        rawResponse: false
        onlyContentUri: true
      ).done (content_uri) =>
        @client.sendImageMessage(envelope.room.id, content_uri, info, info.url).catch (err) =>
          if err.name == 'UnknownDeviceError'
            @handleUnknownDevices err
            @client.sendImageMessage(envelope.room.id, content_uri, info, info.url)
    catch error
      @robot.logger.info "image upload failed: #{error.message}"
    finally
      @robot.logger.info 'image sent'
      callback() if callback?


  send: (envelope, lines...) ->
    last = lines[-1..][0]
    if typeof last is 'function'
      callback = lines.pop()
    syn.eachSeries lines, (@handleURL envelope), ->
      callback() if callback?

  notification: (envelope, strings...) ->
    for str in strings
      @robot.logger.info "Sending to #{envelope.room}: #{str}"
      @client.sendTextMessage(envelope.room, str).catch (err) =>
        if err.name == 'UnknownDeviceError'
          @handleUnknownDevices err
          @client.sendTextMessage(envelope.room, str)

  notificationHtml: (envelope, strings) ->
    stringText = JSON.parse(JSON.stringify(strings)).string
    stringHtml = JSON.parse(JSON.stringify(strings)).stringHtml
    console.dir(strings)
    console.dir([stringText, stringHtml])
    @robot.logger.info "Sending to #{envelope.room}: #{stringText} #{stringHtml}"
    @client.sendHtmlMessage(envelope.room, stringText, stringHtml).catch (err) =>
      if err.name == 'UnknownDeviceError'
        @handleUnknownDevices err
        @client.sendHtmlMessage(envelope.room, stringText, stringHtml)

  emote: (envelope, lines...) ->
    for line in lines
      @client.sendEmoteMessage(envelope.room.id, line).catch (err) =>
        if err.name == 'UnknownDeviceError'
          @handleUnknownDevices err
          @client.sendEmoteMessage(envelope.room.id, line)

  reply: (envelope, lines...) ->
    for line in lines
      @send envelope, "#{envelope.user.name}: #{line}"


  topic: (envelope, lines...) ->
    for line in lines
      @client.sendStateEvent envelope.room.id, "m.room.topic", topic: line, ""


  run: ->
    @robot.logger.info "starting matrix adapter"
    client = sdk.createClient(process.env.HUBOT_MATRIX_HOST_SERVER || 'https://matrix.org')
    client.login 'm.login.password',
      user: process.env.HUBOT_MATRIX_USER || @robot.name
      password: process.env.HUBOT_MATRIX_PASSWORD
    , (err, data) =>

        return @robot.logger.error err if err?

        @user_id       = data.user_id
        @device_id     = @local_storage.getItem 'device_id'
        @device_id     = data.device_id unless @device_id?
        @access_token  = data.access_token

        @local_storage.setItem 'device_id', @device_id

        @robot.logger.info "logged in #{@user_id} on device #{@device_id}"

        @client = sdk.createClient
          baseUrl: process.env.HUBOT_MATRIX_HOST_SERVER || 'https://matrix.org'
          userId: @user_id
          deviceId: @device_id
          accessToken: @access_token
          sessionStore: new sdk.WebStorageSessionStore(@local_storage)

        @client.on 'sync', (state, prevState, data) =>
          switch state
            when "PREPARED"
              @robot.logger.info "synced #{@client.getRooms().length} rooms"
              @emit 'connected'

        createUser = (user) =>
          id: user.userId
          name: user.name
          avatar: user.getAvatarUrl @client.baseUrl, 120, 120, allowDefault: false

        @client.on 'Room.timeline', (event, room, toStartOfTimeline) =>
          if event.getType() == 'm.room.message' and toStartOfTimeline == false
            @client.setPresence "online"

            message     = event.getContent()
            user        = @robot.brain.userForId event.sender.userId
            user.name   = event.sender.name
            user.avatar = event.sender.getAvatarUrl @client.baseUrl, 120, 120, allowDefault: false
            user.room   =
              id: room.roomId
              name: room.name
              private: room.getJoinedMembers().length == 2
              members: room.getJoinedMembers().map createUser
              invitees: room.getMembersWithMembership("invite").map createUser

            if user.id != @user_id
              @receive new TextMessage user, message.body if message.msgtype == "m.text"
              if message.msgtype != "m.text" or message.body.indexOf(@robot.name) != -1
                @client.sendReadReceipt(event)

        @client.on 'RoomMember.membership', (event, member) =>
          if member.membership == 'invite' and member.userId == @user_id
            @client.joinRoom(member.roomId).done =>
              @robot.logger.info "auto-joined #{member.roomId}"

        @client.startClient 0


exports.use = (robot) ->
  new Matrix robot # sentinel
