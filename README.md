# fake_slack

TCP chat server with rooms and server commands.

## Usage

To connect to the server with telnet run:

`telnet fake-slack.fly.dev 5000`

## Commands

- `/delay SECONDS MESSAGE` sends a message after a delay
- `/time` shows the current server time
- `/here` shows who is in the current room
- `/peek ROOM` shows who is in another room
- `/switch ROOM` moves user to another room
- `/room` shows the current room
- `/rooms` shows all rooms
- `/kick USER` kicks a user from the room if you are an admin
- `/exit` leaves the current room and return to the default room
- `/q` quits the server
