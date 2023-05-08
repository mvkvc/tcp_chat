# fake_slack

TCP chat server with rooms and server commands.

## Usage

To connect to the server with telnet run:

`telnet fake-slack.fly.dev 5000`

## Commands

- `/delay SECONDS MESSAGE` send a message after a delay
- `/here` show who is in the current room
- `/peek ROOM` see who is in another room
- `/switch ROOM` switch to another room
- `/room` shows the current room
- `/rooms` shows all rooms
- `/kick USER` kick a user from the room if you are an admin
- `/exit` leave the current room and return to the default room
- `/q` quit the server
