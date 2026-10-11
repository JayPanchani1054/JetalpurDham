package com.jetalpurdham.app

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity (from just_audio_background / audio_service) keeps the
// Flutter engine shared with the background playback service, so kirtans keep
// playing with lock-screen controls when the app is closed.
class MainActivity : AudioServiceActivity()
