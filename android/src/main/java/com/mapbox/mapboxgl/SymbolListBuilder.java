// This file is generated.

// Copyright 2018 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

package com.mapbox.mapboxgl;

import com.mapbox.geojson.Point;
import com.mapbox.mapboxsdk.geometry.LatLng;
import com.mapbox.mapboxsdk.plugins.annotation.Symbol;
import com.mapbox.mapboxsdk.plugins.annotation.SymbolManager;
import com.mapbox.mapboxsdk.plugins.annotation.SymbolOptions;

import java.util.ArrayList;
import java.util.List;

class SymbolListBuilder {
    private final SymbolManager symbolManager;
    private final List<SymbolOptions> symbolOptionsList;

    SymbolListBuilder(SymbolManager symbolManager) {
        this.symbolManager = symbolManager;
        this.symbolOptionsList = new ArrayList<>();
    }

    List<Symbol> build() {
        return symbolManager.create(symbolOptionsList);
    }

    public void setSymbolOptions(List<SymbolOptions> symbolOptionsList) {
        this.symbolOptionsList.clear();
        this.symbolOptionsList.addAll(symbolOptionsList);
    }


}