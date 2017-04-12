# hubot-matrix
## matrix.org adapter for Hubot

This is a [Hubot](http://hubot.github.com/) adapter for the [Matrix](https://matrix.org) protocol.

### Supported features
- Sending/receiving text messages
- Sending image messages
- Automatically joining room

### Config parameters

| Variable                  | Default value      | Description                               |
|---------------------------|--------------------|-------------------------------------------|
| HUBOT_MATRIX_DATA         | ./matrix-data      | location where the session will be stored |
| HUBOT_MATRIX_HOST_SERVER  | https://matrix.org | homeserver URL                            |
| HUBOT_MATRIX_USER         | `robot.name`       | account username                          |
| HUBOT_MATRIX_PASSWORD     | N/A                | account password                          |

You can provide following parameters to always use the same device.

| Variable                  | Default value      | Description                               |
|---------------------------|--------------------|-------------------------------------------|
| HUBOT_MATRIX_ID           | N/A                | account Matrix ID (eg. @hubot:matrix.org) |
| HUBOT_MATRIX_DEVICEID     | N/A                | ID of device to use                       |
| HUBOT_MATRIX_TOKEN        | N/A                | Access token                              |



### License
Copyright 2017 David A Roberts

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
