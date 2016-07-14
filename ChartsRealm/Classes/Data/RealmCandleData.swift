//
//  RealmCandleData.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 23/2/15.

//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation

import Charts
import Realm
import Realm.Dynamic

public class RealmCandleData: CandleChartData
{
    public init(dataSets: [IChartDataSet]?)
    {
        super.init(dataSets: dataSets)
    }
}