// GreenReadARApp.kt
// GreenRead AR — Android Application Entry Point
// Port of GreenReadARApp.swift

package com.greenreadar

import android.app.Application

/**
 * Application class for GreenRead AR.
 * Initializes global resources needed before any Activity launches.
 */
class GreenReadARApp : Application() {

    override fun onCreate() {
        super.onCreate()
        // Future: Initialize analytics, crash reporting, etc.
        // ARCore initialization happens in ARCoreSession when Activity is ready.
    }
}
