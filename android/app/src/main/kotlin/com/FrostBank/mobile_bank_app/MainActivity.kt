package com.FrostBank.mobile_bank_app

import io.flutter.embedding.android.FlutterFragmentActivity

/**
 * FlutterFragmentActivity rather than FlutterActivity, because local_auth needs a
 * FragmentActivity host to show the platform biometric prompt.
 *
 * No FLAG_SECURE, deliberately. It used to be added here, and it did satisfy
 * requirement 5.5 - but by a wide margin. 5.5 asks only that authenticated content
 * be obscured in the operating system task switcher preview; FLAG_SECURE also
 * blocks screenshots and screen recording across the entire application, for every
 * screen, signed in or not. None of that was required, and it makes the build
 * impossible to screenshot for a listing, record for a demo, or capture in a bug
 * report.
 *
 * Requirement 5.5 is still met, on both platforms, by the privacy cover in
 * AppLockScope: it paints over authenticated content on the frame the application
 * stops being resumed, which is the frame the system snapshots for the switcher.
 *
 * That is a weaker guarantee than the flag was, and the difference is worth being
 * honest about. FLAG_SECURE was enforced by the compositor, which simply refused to
 * hand the window contents to anything; the cover depends on Flutter painting a
 * frame before the system takes its snapshot. In practice the lifecycle callback
 * arrives before the activity stops, so the cover lands - and it is the same
 * best-effort guarantee iOS has been living with all along, since there was never
 * any native counterpart there.
 *
 * The other half of the trade is real too: with the flag gone, anything that can
 * record the screen can record a revealed card number or a PIN being entered. That
 * is the cost of being able to demonstrate the application, and it is a decision
 * rather than an oversight.
 *
 * To put the restriction back:
 *
 *     import android.os.Bundle
 *     import android.view.WindowManager
 *
 *     override fun onCreate(savedInstanceState: Bundle?) {
 *         super.onCreate(savedInstanceState)
 *         window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
 *     }
 */
class MainActivity : FlutterFragmentActivity()
