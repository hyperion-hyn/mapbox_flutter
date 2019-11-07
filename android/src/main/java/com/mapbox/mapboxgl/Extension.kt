@file:JvmName("Extension")

package com.mapbox.mapboxgl

import android.os.Build
import android.os.LocaleList
import java.util.*


val Any.language: String
    get() {
        val locale: Locale = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            LocaleList.getDefault().get(0)
        } else
            Locale.getDefault()
        return locale.language
    }

