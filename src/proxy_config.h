
#pragma once
// -----------------------------------------------------------------------------
// FreshMate secure proxy configuration.
//
// The Groq API key must remain on the Render server in its Environment settings.
// Do not put the Groq API key in this file or embed it in the iOS IPA.
//
// Keep this file local and exclude it from Git if you do not want this
// configuration file committed to the repository.
// -----------------------------------------------------------------------------

#define FRESHMATE_PROXY_URL "https://fresh-mate-v2.onrender.com/ai"

// Leave empty only if the server endpoint does not require an app token.
// If the server requires FRESHMATE_APP_TOKEN, configure the matching value
// here; note that any token embedded in an IPA can be extracted.
#define FRESHMATE_APP_TOKEN ""
