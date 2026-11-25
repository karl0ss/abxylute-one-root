#!/system/bin/sh
P=com.levelinfinite.southpole.gamepad.settings.mtk
for c in com.levelinfinite.southpole.gamepad.ota.OTAService \
         com.levelinfinite.southpole.gamepad.settings.report.SettingsDailyCollectReceiver \
         com.levelinfinite.southpole.gamepad.feature.model.FeatureProvider; do
  pm enable "$P/$c"
done
