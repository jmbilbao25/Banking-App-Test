package com.FrostBank.mobile_bank_app

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * FlutterFragmentActivity rather than FlutterActivity, because local_auth needs a
 * FragmentActivity host to show the platform biometric prompt.
 *
 * FLAG_SECURE satisfies requirement 5.5: it keeps authenticated content out of the
 * task switcher preview and out of screenshots. The Flutter side also paints a
 * cover when the application is not resumed, so iOS gets the same treatment.
 */
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    }
}
