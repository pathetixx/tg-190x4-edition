## API credentials

The build reads `TDESKTOP_API_ID` and `TDESKTOP_API_HASH` from the current environment. Do not put deployment credentials into tracked files.

In an x64 Visual Studio command prompt, set them before running the builder:

```bat
set TDESKTOP_API_ID=your_api_id
set TDESKTOP_API_HASH=your_api_hash
call build_tg190x4.bat
```

Create the credentials through Telegram's documented API application process. Use repository secrets with the same names in CI.
