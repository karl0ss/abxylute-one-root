package uk.karl.gpsettings;

import android.app.Activity;
import android.content.ComponentName;
import android.content.Intent;
import android.os.Bundle;
import android.widget.Toast;

public class Main extends Activity {
    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        Intent i = new Intent(Intent.ACTION_MAIN);
        i.setComponent(new ComponentName("com.levelinfinite.southpole.gamepad.settings.mtk",
                "com.levelinfinite.southpole.gamepad.settings.SettingsActivity"));
        i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            startActivity(i);
        } catch (Exception e) {
            Toast.makeText(this, "GamePad Settings is disabled or missing", Toast.LENGTH_LONG).show();
        }
        finish();
    }
}
