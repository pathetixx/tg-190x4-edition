// This is the source code of AyuGram for Desktop.
//
// We do not and cannot prevent the use of our code,
// but be respectful and credit the original author.
//
// Copyright @Radolyn, 2026
#include "ayu/ayu_infra.h"

#include "ayu/ayu_lang.h"
#include "ayu/ayu_settings.h"
#include "ayu/ayu_worker.h"
#include "ayu/data/ayu_database.h"
#include "ayu/ui/ayu_logo.h"
#include "core/application.h"
#include "core/core_settings.h"
#include "features/translator/ayu_translator.h"
#include "lang/lang_cloud_manager.h"
#include "lang/lang_instance.h"
#include "ui/chat/chat_style_radius.h"
#include "utils/rc_manager.h"
#include "window/themes/window_theme.h"

#include <QDir>
#include <QFile>

#ifdef Q_OS_WIN
#include "ayu/utils/windows_utils.h"
#endif

namespace AyuInfra {
namespace {

bool ApplyingDefaults = false;

[[nodiscard]] QString defaultLanguageId() {
	return u"190x4"_q;
}

[[nodiscard]] QString defaultThemePath() {
	return u":/gui/190x4.tdesktop-theme"_q;
}

[[nodiscard]] QString defaultsMarkerPath() {
	return cWorkingDir() + u"tdata/ayu/190x4_defaults"_q;
}

void writeDefaultsMarker() {
	QDir().mkpath(cWorkingDir() + u"tdata/ayu"_q);
	auto marker = QFile(defaultsMarkerPath());
	if (marker.open(QIODevice::WriteOnly)) {
		marker.close();
	}
}

} // namespace

void initLang() {
	QString id = Lang::GetInstance().id();
	QString baseId = Lang::GetInstance().baseId();
	if (id.isEmpty()) {
		LOG(("Language is not loaded"));
		return;
	}
	AyuLanguage::init();
	if (!AyuLanguage::currentInstance()->applyBundledLanguage(id, baseId)) {
		AyuLanguage::currentInstance()->fetchLanguage(id, baseId);
	}
}

void initUiSettings() {
	const auto &settings = AyuSettings::getInstance();
	Ui::SetAppliedBubbleRadius(settings.messageBubbleRadius());
}

void initDatabase() {
	AyuDatabase::initialize();
}

void initWorker() {
	AyuWorker::initialize();
}

void initRCManager() {
	RCManager::getInstance().start();
}

void initTranslator() {
	Ayu::Translator::TranslateManager::init();
}

void initIcon() {
#ifdef Q_OS_WIN
	AyuAssets::loadAppIco();
	reloadAppIconFromTaskBar();
#endif
}

void initDefaults() {
	ApplyingDefaults = !QFile::exists(defaultsMarkerPath());
	if (!ApplyingDefaults) {
		return;
	}
	Lang::CurrentCloudManager().switchToLanguage(defaultLanguageId());
}

void applyDefaultTheme() {
	if (!ApplyingDefaults) {
		return;
	}
	ApplyingDefaults = false;
	Window::Theme::ApplyDefaultWithPath(defaultThemePath());
	writeDefaultsMarker();
}

void init() {
	initLang();
	initDatabase();
	initUiSettings();
	initIcon();
	initWorker();
	initRCManager();
	initTranslator();
	initDefaults();
}

}
