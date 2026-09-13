# mixtape — iOS capabilities

What the iOS app does. Each entry names the screen the user sees and the service that holds the state behind it. See `ios-architecture.md` for how the layers fit together, and `../jellyfin-openapi.json` for the API contract.

## Connect and sign in

1. **Connect to one Jellyfin server by URL.** `ServerEntryScreen` takes a URL, `SessionService.validateServer(urlText:)` calls `/System/Info/Public`, and the server's name and id come back as a `ServerIdentity`. Plain HTTP over a LAN is supported.
2. **Sign in with a username and password.** `SignInScreen` posts to `/Users/AuthenticateByName` through `SignInWithPasswordUseCase`.
3. **Sign in with Quick Connect.** `QuickConnectScreen` shows the code from `/QuickConnect/Initiate` and polls `/QuickConnect/Connect` until the user authorises it elsewhere, then exchanges the secret for a token. The Quick Connect route appears when the server reports it enabled.
4. **Stay signed in.** The access token, user, server URL and device id are stored in the Keychain by `KeychainSessionStore`. `RootScreen` restores the session at launch behind `SplashScreen`.
5. **Sign out.** `SettingsScreen` shows the server name and the signed-in user, and a Sign Out button. Signing out clears the Keychain and fans out through `AppContainer` so every service drops its caches and every player stops.
6. **Recover from an expired session.** `SessionService` is the single place a `.sessionExpired` error is handled; it returns the app to the sign-in flow.

## Browse

7. **List the user's libraries.** `LibraryListScreen` reads `/UserViews` and shows the music libraries the user can see.
8. **Browse a music library.** The wallet (below) for albums, then `AlbumDetailScreen` with the album art, album artist, year and track list.
9. **Remote images.** Album art comes from `/Items/{itemId}/Images/...`. `ImageService` holds it in an in-memory cache capped at 120 MB, and decodes off the main actor.

## The Wallet

10. **The wallet.** The Music tab is a CD wallet: sideways pages of album sleeves for one music library. Tapping a sleeve pulls the disc out into the album detail. Music libraries beyond the first stay reachable from the Libraries tab, as wallets too.
11. **Putting an album back.** When an album plays to its end, playback stops, the now-playing sheet dismisses, any pushed album detail pops, and the wallet pages to that album's sleeve and pulses it home. If the album's page has not been loaded yet, the wallet pages the library in further first and completes the return when it arrives.

## Play music

12. **Play an album.** `MusicPlayerService.queue` holds exactly one album's tracks. Playing an album replaces the queue with that album's track list, starting at the tapped track.
13. **Track controls.** Play, pause, previous, next and a scrubber, on `NowPlayingScreen`. The seek is sent once, when the drag ends.
14. **Mini player.** Whenever music is active a mini player docks in the tab bar's bottom accessory, showing the current track. Tapping it presents the now-playing sheet.
15. **Background audio.** The `AVAudioSession` `.playback` category plus the `audio` background mode keep playback running when the app leaves the foreground.
16. **Lock screen and remote controls.** `MPNowPlayingInfoCenter` carries the title, artist, artwork and elapsed time; `MPRemoteCommandCenter` accepts play, pause, next and previous, with next disabled on the last track of the album.
17. **Interruptions and route changes.** A phone call or another app's audio pauses playback and resumes it when the system says it should. Unplugging headphones pauses. A media-services reset rebuilds the audio session.

## Report to the server

18. **Playback start.** Reported to `/Sessions/Playing` when play begins.
19. **Playback progress.** Reported to `/Sessions/Playing/Progress` every 10 seconds while playing, and on pause and after a seek. Never more often than that.
20. **Playback stop.** Reported to `/Sessions/Playing/Stopped` when playback ends or is stopped, so the server keeps the resume point.

## Presentation quality

21. **Liquid Glass chrome with a Reduce Transparency fallback.** Every glass surface goes through one modifier that paints an opaque background when the accessibility setting is on. `scripts/check-glass-fallback.sh` checks that no glass surface skips it.
22. **Accessibility identifiers on every screen.** Held as constants in `MixtapeKit/Sources/MixtapePresentation/Identifiers/`, one file per screen.
23. **Uniform load, empty and failure states.** `LoadState` carries idle, loading, loaded and failed through every service, `RetryView` offers the retry, and `MixtapeError+Message` turns a domain error into the message shown.
