# mixtape features

## v1

## Launch

- Show a loading screen while restoring the saved session.
- Stay signed in between launches using securely stored session details.
- Return to sign-in when the session expires.

## Server Entry

- Enter a Jellyfin server address, including a local HTTP server and custom port.
- Validate the server before continuing to sign-in.
- Enable Connect when an address is entered and disable it while connecting.
- Show connection progress and readable validation errors.
- Present a minimal welcome screen with the mixtape name and server-address prompt

## Sign In

- Sign in with a username and password.
- Hide the password while typing.
- Show the selected server's name above the sign-in form.
- Show sign-in progress and authentication errors.
- Offer Quick Connect as an alternative to password sign-in.
- Change the server before signing in.

## Quick Connect

- Display a sign-in code with instructions for approving it in Jellyfin.
- Wait for approval and complete sign-in automatically.
- Retry after a failed Quick Connect attempt.
- Cancel Quick Connect and return to password sign-in.

## Wallets

- Show as horizontal scrolling list with title
- Show a + card at the end to add to the wallet
- Shows thumbnail with album and artist underneath
- Show curated wallets based on genera
- Show curated wallets based on most played
- Show "Random" creates random, single wallet
  - Options random
  - Options random + least played
- Open each music library as its own album wallet tapping on wallet title
- Show loading progress, an empty-library message, and retryable errors.

## Music / Album Wallet

- Open the first music library from the Music screen.
- Browse album artwork in a CD wallet with rounded plastic sleeves and a light sheen.
- Swipe horizontally through fixed pages of four albums on compact screens or nine on regular-width screens.
- Keep empty sleeves visible on partially filled pages.
- Show the current page and total page count below the wallet.
- Load more albums as the listener pages through the library.
- Open an album by tapping its sleeve, with an artwork transition into Album Detail.
- Return to the finished album's wallet page and briefly highlight its sleeve.
- Use placeholder artwork when an album cover is unavailable.
- Show empty-wallet and missing-music-library messages, loading progress, and retryable errors.
- Remove the sleeve sheen when Reduce Transparency is enabled.

## Mini Player

- Show the current track's artwork and title in a compact playback bar.
- Play or pause without opening the full player.
- Request the Now Playing sheet by tapping the artwork or track title.
- Hide the bar when playback is no longer active.

## Lock Screen / System Playback Controls

- Show track title, artist, artwork, duration, and playback progress in the system Now Playing display.
- Control play, pause, previous track, and next track from system or remote controls.
- Disable the next-track command at the end of the album.

## Settings

- Show the connected server name and signed-in username.
- Sign out and clear the saved session.
- Stop playback and clear session-specific cached data on sign-out.
