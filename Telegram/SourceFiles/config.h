/*
This file is part of Telegram Desktop,
the official desktop application for the Telegram messaging service.

For license and copyright information please follow this link:
https://github.com/telegramdesktop/tdesktop/blob/master/LEGAL
*/
#pragma once

#include "settings.h"

enum {
	MaxSelectedItems = 100,

	LocalEncryptIterCount = 4000, // key derivation iteration count
	LocalEncryptNoPwdIterCount = 4, // key derivation iteration count without pwd (not secure anyway)
	LocalEncryptSaltSize = 32, // 256 bit

	AutoSearchTimeout = 900, // 0.9 secs

	PreloadHeightsCount = 3, // when 3 screens to scroll left make a preload request

	SearchPeopleLimit = 20,

	WebPageUserId = 701000,

	UpdateDelayConstPart = 8 * 3600, // 8 hour min time between update check requests
	UpdateDelayRandPart = 8 * 3600, // 8 hour max - min time between update check requests

	WrongPasscodeTimeout = 1500,

	ChoosePeerByDragTimeout = 1000, // 1 second mouse not moved to choose dialog when dragging a file
};

inline const char *cGUIDStr() {
#ifndef OS_MAC_STORE
	static const char *gGuidStr = "{87A94AB0-E370-4cde-98D3-ACC110C59666}";
#else // OS_MAC_STORE
	static const char *gGuidStr = "{E51FB841-8C0B-4EF9-9E9E-5A0078567666}";
#endif // OS_MAC_STORE

	return gGuidStr;
}

static const char *UpdatesPublicKey = "\
-----BEGIN RSA PUBLIC KEY-----\n\
MIIBCgKCAQEAvFylS0TudKNHpM1Jm4VEaGLwygaNIE4tnPjf9PpbHsPlomV4KSev\n\
PIq4IGv56SncuBF48UlescwLzKAHzlkSWa6S9TOvc6vwM14c9I4nW/To89R8NcJH\n\
Wn2z/QWCQzBkICHMD3i8jX7wAt+KMlsb6/XqVMX45AJ7edqCTIH9j8d+/0JUOcMZ\n\
y4c2kxufGwJBA2LvevjaC+WypIF2AcdbTNPtgVox06KthoM1otpHw2NztC5AIEyd\n\
FoAxZ6dfxOUZNI+FsThj9WqiB1Es+wi44HWVz3v7AVW9+rUWDFlo9O5AmcyAvTaf\n\
ym4RA02TO7nHont2TEBihdwiBOyQj2Sp+wIDAQAB\n\
-----END RSA PUBLIC KEY-----\
";

static const char *UpdatesPublicBetaKey = "\
-----BEGIN RSA PUBLIC KEY-----\n\
MIIBCgKCAQEAp6eNb0BqU0ekuy2V+tEfzt/y8pTJscj/N1ohmr6iyAKS9pL/lnZU\n\
GsdpxFn9ffnaqre1f2oGQsZThh5/cUojiTHc4ujF1FWy5pXiud4gaBkJdwssWC2w\n\
Mu+cjId3Y7wUQHWN8FwU1UJXg2t7NKRWc6tB32VCdk/RHE3LBhKzfu5zKrXUWFoB\n\
S8czjzbZ2InS4A0PqbjTI8dZbiGoK3xk7Euh9VusglGzBQqfcnnk0EfFRrmZeHKX\n\
PlDhDMLrz8hpEZv5oULFflVUyokqQrS0pUAzWTC317H+rc0mmmlk92yd3X8QiQ/6\n\
CAkYdZlO0mFe2LdIjfMA532SStt8eWc1ewIDAQAB\n\
-----END RSA PUBLIC KEY-----\
";

#if defined TDESKTOP_API_ID && defined TDESKTOP_API_HASH

constexpr auto ApiId = TDESKTOP_API_ID;
constexpr auto ApiHash = QT_STRINGIFY(TDESKTOP_API_HASH);

#else // TDESKTOP_API_ID && TDESKTOP_API_HASH

// To build your version of Telegram Desktop you're required to provide
// your own 'api_id' and 'api_hash' for the Telegram API access.
//
// How to obtain your 'api_id' and 'api_hash' is described here:
// https://core.telegram.org/api/obtaining_api_id
//
// If you're building the application not for deployment,
// but only for test purposes you can comment out the error below.
//
// This will allow you to use TEST ONLY 'api_id' and 'api_hash' which are
// very limited by the Telegram API server.
//
// Your users will start getting internal server errors on login
// if you deploy an app using those 'api_id' and 'api_hash'.

#error You are required to provide API_ID and API_HASH.

constexpr auto ApiId = 17349;
constexpr auto ApiHash = "344583e45741c457fe1862106095a5eb";

#endif // TDESKTOP_API_ID && TDESKTOP_API_HASH

#if Q_BYTE_ORDER == Q_BIG_ENDIAN
#error "Only little endian is supported!"
#endif // Q_BYTE_ORDER == Q_BIG_ENDIAN

#if (TDESKTOP_ALPHA_VERSION != 0)

// Private key for downloading closed alphas.
#include "../../../DesktopPrivate/alpha_private.h"

#else
static const char *AlphaPrivateKey = "";
#endif

extern QString gKeyFile;
inline const QString &cDataFile() {
	if (!gKeyFile.isEmpty()) return gKeyFile;
	static const QString res(u"data"_q);
	return res;
}

inline const QRegularExpression &cRussianLetters() {
	static QRegularExpression regexp(QString::fromUtf8("[а-яА-ЯёЁ]"));
	return regexp;
}
