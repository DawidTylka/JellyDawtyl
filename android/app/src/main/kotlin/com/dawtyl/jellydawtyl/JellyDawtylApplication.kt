package com.dawtyl.jellydawtyl

import android.app.Application
import androidx.work.Configuration
import java.util.concurrent.Executors

class JellyDawtylApplication : Application(), Configuration.Provider {
    override val workManagerConfiguration: Configuration
        get() = Configuration.Builder()
            // Keep several episode transcodes from competing for the server and
            // removable-storage writer at the same time.
            .setExecutor(Executors.newFixedThreadPool(6))
            .build()
}
