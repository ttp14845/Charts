//
//  PieChartRenderer.swift
//  Charts
//
//  Created by Daniel Cohen Gindi on 4/3/15.
//
//  Copyright 2015 Daniel Cohen Gindi & Philipp Jahoda
//  A port of MPAndroidChart for iOS
//  Licensed under Apache License 2.0
//
//  https://github.com/danielgindi/Charts
//

import Foundation
import CoreGraphics

#if !os(OSX)
    import UIKit
#endif


public class PieChartRenderer: ChartDataRendererBase
{
    public weak var chart: PieChartView?
    
    public init(chart: PieChartView, animator: ChartAnimator?, viewPortHandler: ChartViewPortHandler)
    {
        super.init(animator: animator, viewPortHandler: viewPortHandler)
        
        self.chart = chart
    }
    
    public override func drawData(context context: CGContext)
    {
        guard let chart = chart else { return }
        
        let pieData = chart.data
        
        if (pieData != nil)
        {
            for set in pieData!.dataSets as! [IPieChartDataSet]
            {
                if set.isVisible && set.entryCount > 0
                {
                    drawDataSet(context: context, dataSet: set)
                }
            }
        }
    }
    
    public func calculateMinimumRadiusForSpacedSlice(
        center center: CGPoint,
        radius: CGFloat,
        angle: CGFloat,
        arcStartPointX: CGFloat,
        arcStartPointY: CGFloat,
        startAngle: CGFloat,
        sweepAngle: CGFloat) -> CGFloat
    {
        let angleMiddle = startAngle + sweepAngle / 2.0
        
        // Other point of the arc
        let arcEndPointX = center.x + radius * cos((startAngle + sweepAngle) * ChartUtils.Math.FDEG2RAD)
        let arcEndPointY = center.y + radius * sin((startAngle + sweepAngle) * ChartUtils.Math.FDEG2RAD)
        
        // Middle point on the arc
        let arcMidPointX = center.x + radius * cos(angleMiddle * ChartUtils.Math.FDEG2RAD)
        let arcMidPointY = center.y + radius * sin(angleMiddle * ChartUtils.Math.FDEG2RAD)
        
        // This is the base of the contained triangle
        let basePointsDistance = sqrt(
            pow(arcEndPointX - arcStartPointX, 2) +
                pow(arcEndPointY - arcStartPointY, 2))
        
        // After reducing space from both sides of the "slice",
        //   the angle of the contained triangle should stay the same.
        // So let's find out the height of that triangle.
        let containedTriangleHeight = (basePointsDistance / 2.0 *
            tan((180.0 - angle) / 2.0 * ChartUtils.Math.FDEG2RAD))
        
        // Now we subtract that from the radius
        var spacedRadius = radius - containedTriangleHeight
        
        // And now subtract the height of the arc that's between the triangle and the outer circle
        spacedRadius -= sqrt(
            pow(arcMidPointX - (arcEndPointX + arcStartPointX) / 2.0, 2) +
                pow(arcMidPointY - (arcEndPointY + arcStartPointY) / 2.0, 2))
        
        return spacedRadius
    }
    
    public func drawDataSet(context context: CGContext, dataSet: IPieChartDataSet)
    {
        guard let
            chart = chart,
            data = chart.data,
            animator = animator
            else {return }
        
        var angle: CGFloat = 0.0
        let rotationAngle = chart.rotationAngle
        
        let phaseX = animator.phaseX
        let phaseY = animator.phaseY
        
        let entryCount = dataSet.entryCount
        var drawAngles = chart.drawAngles
        let center = chart.centerCircleBox
        let radius = chart.radius
        let drawInnerArc = chart.drawHoleEnabled && !chart.drawSlicesUnderHoleEnabled
        let userInnerRadius = drawInnerArc ? radius * chart.holeRadiusPercent : 0.0
        
        var visibleAngleCount = 0
        for j in 0 ..< entryCount
        {
            guard let e = dataSet.entryForIndex(j) else { continue }
            if ((abs(e.y) > 0.000001))
            {
                visibleAngleCount += 1
            }
        }
        
        let sliceSpace = visibleAngleCount <= 1 ? 0.0 : dataSet.sliceSpace

        CGContextSaveGState(context)
        
        for j in 0 ..< entryCount
        {
            let sliceAngle = drawAngles[j]
            var innerRadius = userInnerRadius
            
            guard let e = dataSet.entryForIndex(j) else { continue }
            
            // draw only if the value is greater than zero
            if ((abs(e.y) > 0.000001))
            {
                if (!chart.needsHighlight(xValue: e.x,
                    dataSetIndex: data.indexOfDataSet(dataSet)))
                {
                    let accountForSliceSpacing = sliceSpace > 0.0 && sliceAngle <= 180.0
                    
                    CGContextSetFillColorWithColor(context, dataSet.colorAt(j).CGColor)
                    
                    let sliceSpaceAngleOuter = visibleAngleCount == 1 ?
                        0.0 :
                        sliceSpace / (ChartUtils.Math.FDEG2RAD * radius)
                    let startAngleOuter = rotationAngle + (angle + sliceSpaceAngleOuter / 2.0) * phaseY
                    var sweepAngleOuter = (sliceAngle - sliceSpaceAngleOuter) * phaseY
                    if (sweepAngleOuter < 0.0)
                    {
                        sweepAngleOuter = 0.0
                    }
                    
                    let arcStartPointX = center.x + radius * cos(startAngleOuter * ChartUtils.Math.FDEG2RAD)
                    let arcStartPointY = center.y + radius * sin(startAngleOuter * ChartUtils.Math.FDEG2RAD)

                    let path = CGPathCreateMutable()
                    
                    CGPathMoveToPoint(
                        path,
                        nil,
                        arcStartPointX,
                        arcStartPointY)
                    CGPathAddRelativeArc(
                        path,
                        nil,
                        center.x,
                        center.y,
                        radius,
                        startAngleOuter * ChartUtils.Math.FDEG2RAD,
                        sweepAngleOuter * ChartUtils.Math.FDEG2RAD)

                    if drawInnerArc &&
                        (innerRadius > 0.0 || accountForSliceSpacing)
                    {
                        if accountForSliceSpacing
                        {
                            var minSpacedRadius = calculateMinimumRadiusForSpacedSlice(
                                center: center,
                                radius: radius,
                                angle: sliceAngle * phaseY,
                                arcStartPointX: arcStartPointX,
                                arcStartPointY: arcStartPointY,
                                startAngle: startAngleOuter,
                                sweepAngle: sweepAngleOuter)
                            if minSpacedRadius < 0.0
                            {
                                minSpacedRadius = -minSpacedRadius
                            }
                            innerRadius = min(max(innerRadius, minSpacedRadius), radius)
                        }
                        
                        let sliceSpaceAngleInner = visibleAngleCount == 1 || innerRadius == 0.0 ?
                            0.0 :
                            sliceSpace / (ChartUtils.Math.FDEG2RAD * innerRadius)
                        let startAngleInner = rotationAngle + (angle + sliceSpaceAngleInner / 2.0) * phaseY
                        var sweepAngleInner = (sliceAngle - sliceSpaceAngleInner) * phaseY
                        if (sweepAngleInner < 0.0)
                        {
                            sweepAngleInner = 0.0
                        }
                        let endAngleInner = startAngleInner + sweepAngleInner
                        
                        CGPathAddLineToPoint(
                            path,
                            nil,
                            center.x + innerRadius * cos(endAngleInner * ChartUtils.Math.FDEG2RAD),
                            center.y + innerRadius * sin(endAngleInner * ChartUtils.Math.FDEG2RAD))
                        CGPathAddRelativeArc(
                            path,
                            nil,
                            center.x,
                            center.y,
                            innerRadius,
                            endAngleInner * ChartUtils.Math.FDEG2RAD,
                            -sweepAngleInner * ChartUtils.Math.FDEG2RAD)
                    }
                    else
                    {
                        if accountForSliceSpacing
                        {
                            let angleMiddle = startAngleOuter + sweepAngleOuter / 2.0
                            
                            let sliceSpaceOffset =
                                calculateMinimumRadiusForSpacedSlice(
                                    center: center,
                                    radius: radius,
                                    angle: sliceAngle * phaseY,
                                    arcStartPointX: arcStartPointX,
                                    arcStartPointY: arcStartPointY,
                                    startAngle: startAngleOuter,
                                    sweepAngle: sweepAngleOuter)

                            let arcEndPointX = center.x + sliceSpaceOffset * cos(angleMiddle * ChartUtils.Math.FDEG2RAD)
                            let arcEndPointY = center.y + sliceSpaceOffset * sin(angleMiddle * ChartUtils.Math.FDEG2RAD)
                            
                            CGPathAddLineToPoint(
                                path,
                                nil,
                                arcEndPointX,
                                arcEndPointY)
                        }
                        else
                        {
                            CGPathAddLineToPoint(
                                path,
                                nil,
                                center.x,
                                center.y)
                        }
                    }
                    
                    CGPathCloseSubpath(path)
                    
                    CGContextBeginPath(context)
                    CGContextAddPath(context, path)
                    CGContextEOFillPath(context)
                }
            }
            
            angle += sliceAngle * phaseX
        }
        
        CGContextRestoreGState(context)
    }
    
    public override func drawValues(context context: CGContext)
    {
        guard let
            chart = chart,
            data = chart.data,
            animator = animator
            else { return }
        
        let center = chart.centerCircleBox
        
        // get whole the radius
        let radius = chart.radius
        let rotationAngle = chart.rotationAngle
        var drawAngles = chart.drawAngles
        var absoluteAngles = chart.absoluteAngles
        
        let phaseX = animator.phaseX
        let phaseY = animator.phaseY
        
        var labelRadiusOffset = radius / 10.0 * 3.0
        
        if chart.drawHoleEnabled
        {
            labelRadiusOffset = (radius - (radius * chart.holeRadiusPercent)) / 2.0
        }
        
        let labelRadius = radius - labelRadiusOffset
        
        var dataSets = data.dataSets
        
        let yValueSum = (data as! PieChartData).yValueSum
        
        let drawXVals = chart.isDrawSliceTextEnabled
        let usePercentValuesEnabled = chart.usePercentValuesEnabled
        
        var angle: CGFloat = 0.0
        var xIndex = 0
        
        CGContextSaveGState(context)
        defer { CGContextRestoreGState(context) }
        
        for i in 0 ..< dataSets.count
        {
            guard let dataSet = dataSets[i] as? IPieChartDataSet else { continue }
            
            let drawYVals = dataSet.isDrawValuesEnabled
            
            if (!drawYVals && !drawXVals)
            {
                continue
            }
            
            let xValuePosition = dataSet.xValuePosition
            let yValuePosition = dataSet.yValuePosition
            
            let valueFont = dataSet.valueFont
            let lineHeight = valueFont.lineHeight
            
            guard let formatter = dataSet.valueFormatter else { continue }
            
            for j in 0 ..< dataSet.entryCount
            {
                guard let e = dataSet.entryForIndex(j) else { continue }
                let pe = e as? PieChartDataEntry
                
                if (xIndex == 0)
                {
                    angle = 0.0
                }
                else
                {
                    angle = absoluteAngles[xIndex - 1] * phaseX
                }
                
                let sliceAngle = drawAngles[xIndex]
                let sliceSpace = dataSet.sliceSpace
                let sliceSpaceMiddleAngle = sliceSpace / (ChartUtils.Math.FDEG2RAD * labelRadius)
                
                // offset needed to center the drawn text in the slice
                let angleOffset = (sliceAngle - sliceSpaceMiddleAngle / 2.0) / 2.0

                angle = angle + angleOffset
                
                let transformedAngle = rotationAngle + angle * phaseY
                
                let value = usePercentValuesEnabled ? e.y / yValueSum * 100.0 : e.y
                let valueText = formatter.stringFromNumber(value)!
                
                let sliceXBase = cos(transformedAngle * ChartUtils.Math.FDEG2RAD)
                let sliceYBase = sin(transformedAngle * ChartUtils.Math.FDEG2RAD)
                
                let drawXOutside = drawXVals && xValuePosition == .OutsideSlice
                let drawYOutside = drawYVals && yValuePosition == .OutsideSlice
                let drawXInside = drawXVals && xValuePosition == .InsideSlice
                let drawYInside = drawYVals && yValuePosition == .InsideSlice
                
                if drawXOutside || drawYOutside
                {
                    let valueLineLength1 = dataSet.valueLinePart1Length
                    let valueLineLength2 = dataSet.valueLinePart2Length
                    let valueLinePart1OffsetPercentage = dataSet.valueLinePart1OffsetPercentage
                    
                    var pt2: CGPoint
                    var labelPoint: CGPoint
                    var align: NSTextAlignment
                    
                    var line1Radius: CGFloat
                    
                    if chart.drawHoleEnabled
                    {
                        line1Radius = (radius - (radius * chart.holeRadiusPercent)) * valueLinePart1OffsetPercentage + (radius * chart.holeRadiusPercent)
                    }
                    else
                    {
                        line1Radius = radius * valueLinePart1OffsetPercentage
                    }
                    
                    let polyline2Length = dataSet.valueLineVariableLength
                        ? labelRadius * valueLineLength2 * abs(sin(transformedAngle * ChartUtils.Math.FDEG2RAD))
                        : labelRadius * valueLineLength2;
                    
                    let pt0 = CGPoint(
                        x: line1Radius * sliceXBase + center.x,
                        y: line1Radius * sliceYBase + center.y)
                    
                    let pt1 = CGPoint(
                        x: labelRadius * (1 + valueLineLength1) * sliceXBase + center.x,
                        y: labelRadius * (1 + valueLineLength1) * sliceYBase + center.y)
                    
                    if transformedAngle % 360.0 >= 90.0 && transformedAngle % 360.0 <= 270.0
                    {
                        pt2 = CGPoint(x: pt1.x - polyline2Length, y: pt1.y)
                        align = .Right
                        labelPoint = CGPoint(x: pt2.x - 5, y: pt2.y - lineHeight)
                    }
                    else
                    {
                        pt2 = CGPoint(x: pt1.x + polyline2Length, y: pt1.y)
                        align = .Left
                        labelPoint = CGPoint(x: pt2.x + 5, y: pt2.y - lineHeight)
                    }
                    
                    if dataSet.valueLineColor != nil
                    {
                        CGContextSetStrokeColorWithColor(context, dataSet.valueLineColor!.CGColor)
                        CGContextSetLineWidth(context, dataSet.valueLineWidth);
                        
                        CGContextMoveToPoint(context, pt0.x, pt0.y)
                        CGContextAddLineToPoint(context, pt1.x, pt1.y)
                        CGContextAddLineToPoint(context, pt2.x, pt2.y)
                        
                        CGContextDrawPath(context, CGPathDrawingMode.Stroke);
                    }
                    
                    if drawXOutside && drawYOutside
                    {
                        ChartUtils.drawText(
                            context: context,
                            text: valueText,
                            point: labelPoint,
                            align: align,
                            attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: dataSet.valueTextColorAt(j)]
                        )
                        
                        if (j < data.entryCount && pe?.label != nil)
                        {
                            ChartUtils.drawText(
                                context: context,
                                text: pe!.label!,
                                point: CGPoint(x: labelPoint.x, y: labelPoint.y + lineHeight),
                                align: align,
                                attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: dataSet.valueTextColorAt(j)]
                            )
                        }
                    }
                    else if drawXOutside && pe?.label != nil
                    {
                        ChartUtils.drawText(
                            context: context,
                            text: pe!.label!,
                            point: CGPoint(x: labelPoint.x, y: labelPoint.y + lineHeight / 2.0),
                            align: align,
                            attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: dataSet.valueTextColorAt(j)]
                        )
                    }
                    else if drawYOutside
                    {
                        ChartUtils.drawText(
                            context: context,
                            text: valueText,
                            point: CGPoint(x: labelPoint.x, y: labelPoint.y + lineHeight / 2.0),
                            align: align,
                            attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: dataSet.valueTextColorAt(j)]
                        )
                    }
                }
                
                if drawXInside || drawYInside
                {
                    // calculate the text position
                    let x = labelRadius * sliceXBase + center.x
                    let y = labelRadius * sliceYBase + center.y - lineHeight
                 
                    if drawXInside && drawYInside
                    {
                        ChartUtils.drawText(
                            context: context,
                            text: valueText,
                            point: CGPoint(x: x, y: y),
                            align: .Center,
                            attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: dataSet.valueTextColorAt(j)]
                        )
                        
                        if j < data.entryCount && pe?.label != nil
                        {
                            ChartUtils.drawText(
                                context: context,
                                text: pe!.label!,
                                point: CGPoint(x: x, y: y + lineHeight),
                                align: .Center,
                                attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: dataSet.valueTextColorAt(j)]
                            )
                        }
                    }
                    else if drawXInside && pe?.label != nil
                    {
                        ChartUtils.drawText(
                            context: context,
                            text: pe!.label!,
                            point: CGPoint(x: x, y: y + lineHeight / 2.0),
                            align: .Center,
                            attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: dataSet.valueTextColorAt(j)]
                        )
                    }
                    else if drawYInside
                    {
                        ChartUtils.drawText(
                            context: context,
                            text: valueText,
                            point: CGPoint(x: x, y: y + lineHeight / 2.0),
                            align: .Center,
                            attributes: [NSFontAttributeName: valueFont, NSForegroundColorAttributeName: dataSet.valueTextColorAt(j)]
                        )
                    }
                }
                
                xIndex += 1
            }
        }
    }
    
    public override func drawExtras(context context: CGContext)
    {
        drawHole(context: context)
        drawCenterText(context: context)
    }
    
    /// draws the hole in the center of the chart and the transparent circle / hole
    private func drawHole(context context: CGContext)
    {
        guard let
            chart = chart,
            animator = animator
            else { return }
        
        if (chart.drawHoleEnabled)
        {
            CGContextSaveGState(context)
            
            let radius = chart.radius
            let holeRadius = radius * chart.holeRadiusPercent
            let center = chart.centerCircleBox
            
            if let holeColor = chart.holeColor
            {
                if holeColor != NSUIColor.clearColor()
                {
                    // draw the hole-circle
                    CGContextSetFillColorWithColor(context, chart.holeColor!.CGColor)
                    CGContextFillEllipseInRect(context, CGRect(x: center.x - holeRadius, y: center.y - holeRadius, width: holeRadius * 2.0, height: holeRadius * 2.0))
                }
            }
            
            // only draw the circle if it can be seen (not covered by the hole)
            if let transparentCircleColor = chart.transparentCircleColor
            {
                if transparentCircleColor != NSUIColor.clearColor() &&
                    chart.transparentCircleRadiusPercent > chart.holeRadiusPercent
                {
                    let alpha = animator.phaseX * animator.phaseY
                    let secondHoleRadius = radius * chart.transparentCircleRadiusPercent
                    
                    // make transparent
                    CGContextSetAlpha(context, alpha);
                    CGContextSetFillColorWithColor(context, transparentCircleColor.CGColor)
                    
                    // draw the transparent-circle
                    CGContextBeginPath(context)
                    CGContextAddEllipseInRect(context, CGRect(
                        x: center.x - secondHoleRadius,
                        y: center.y - secondHoleRadius,
                        width: secondHoleRadius * 2.0,
                        height: secondHoleRadius * 2.0))
                    CGContextAddEllipseInRect(context, CGRect(
                        x: center.x - holeRadius,
                        y: center.y - holeRadius,
                        width: holeRadius * 2.0,
                        height: holeRadius * 2.0))
                    CGContextEOFillPath(context)
                }
            }
            
            CGContextRestoreGState(context)
        }
    }
    
    /// draws the description text in the center of the pie chart makes most sense when center-hole is enabled
    private func drawCenterText(context context: CGContext)
    {
        guard let
            chart = chart,
            centerAttributedText = chart.centerAttributedText
            else { return }
        
        if chart.drawCenterTextEnabled && centerAttributedText.length > 0
        {
            let center = chart.centerCircleBox
            let innerRadius = chart.drawHoleEnabled && !chart.drawSlicesUnderHoleEnabled ? chart.radius * chart.holeRadiusPercent : chart.radius
            let holeRect = CGRect(x: center.x - innerRadius, y: center.y - innerRadius, width: innerRadius * 2.0, height: innerRadius * 2.0)
            var boundingRect = holeRect
            
            if (chart.centerTextRadiusPercent > 0.0)
            {
                boundingRect = CGRectInset(boundingRect, (boundingRect.width - boundingRect.width * chart.centerTextRadiusPercent) / 2.0, (boundingRect.height - boundingRect.height * chart.centerTextRadiusPercent) / 2.0)
            }
            
            let textBounds = centerAttributedText.boundingRectWithSize(boundingRect.size, options: [.UsesLineFragmentOrigin, .UsesFontLeading, .TruncatesLastVisibleLine], context: nil)
            
            var drawingRect = boundingRect
            drawingRect.origin.x += (boundingRect.size.width - textBounds.size.width) / 2.0
            drawingRect.origin.y += (boundingRect.size.height - textBounds.size.height) / 2.0
            drawingRect.size = textBounds.size
            
            CGContextSaveGState(context)

            let clippingPath = CGPathCreateWithEllipseInRect(holeRect, nil)
            CGContextBeginPath(context)
            CGContextAddPath(context, clippingPath)
            CGContextClip(context)
            
            centerAttributedText.drawWithRect(drawingRect, options: [.UsesLineFragmentOrigin, .UsesFontLeading, .TruncatesLastVisibleLine], context: nil)
            
            CGContextRestoreGState(context)
        }
    }
    
    public override func drawHighlighted(context context: CGContext, indices: [ChartHighlight])
    {
        guard let
            chart = chart,
            data = chart.data,
            animator = animator
            else { return }
        
        CGContextSaveGState(context)
        
        let phaseX = animator.phaseX
        let phaseY = animator.phaseY
        
        var angle: CGFloat = 0.0
        let rotationAngle = chart.rotationAngle
        
        var drawAngles = chart.drawAngles
        var absoluteAngles = chart.absoluteAngles
        let center = chart.centerCircleBox
        let radius = chart.radius
        let drawInnerArc = chart.drawHoleEnabled && !chart.drawSlicesUnderHoleEnabled
        let userInnerRadius = drawInnerArc ? radius * chart.holeRadiusPercent : 0.0
        
        for i in 0 ..< indices.count
        {
            // get the index to highlight
            let x = indices[i].x
            if x >= Double(drawAngles.count)
            {
                continue
            }
            
            guard let set = data.getDataSetByIndex(indices[i].dataSetIndex) as? IPieChartDataSet else { continue }
            
            if !set.isHighlightEnabled
            {
                continue
            }
            
            let entryIndex = set.entryIndex(x: x, rounding: .Closest)

            let entryCount = set.entryCount
            var visibleAngleCount = 0
            for j in 0 ..< entryCount
            {
                guard let e = set.entryForIndex(j) else { continue }
                if ((abs(e.y) > 0.000001))
                {
                    visibleAngleCount += 1
                }
            }
            
            if (x == 0)
            {
                angle = 0.0
            }
            else
            {
                angle = absoluteAngles[entryIndex - 1] * phaseX
            }
            
            let sliceSpace = visibleAngleCount <= 1 ? 0.0 : set.sliceSpace
            
            let sliceAngle = drawAngles[entryIndex]
            var innerRadius = userInnerRadius
            
            let shift = set.selectionShift
            let highlightedRadius = radius + shift
            
            let accountForSliceSpacing = sliceSpace > 0.0 && sliceAngle <= 180.0
            
            CGContextSetFillColorWithColor(context, set.colorAt(entryIndex).CGColor)
            
            let sliceSpaceAngleOuter = visibleAngleCount == 1 ?
                0.0 :
                sliceSpace / (ChartUtils.Math.FDEG2RAD * radius)
            
            let sliceSpaceAngleShifted = visibleAngleCount == 1 ?
                0.0 :
                sliceSpace / (ChartUtils.Math.FDEG2RAD * highlightedRadius)
            
            let startAngleOuter = rotationAngle + (angle + sliceSpaceAngleOuter / 2.0) * phaseY
            var sweepAngleOuter = (sliceAngle - sliceSpaceAngleOuter) * phaseY
            if (sweepAngleOuter < 0.0)
            {
                sweepAngleOuter = 0.0
            }
            
            let startAngleShifted = rotationAngle + (angle + sliceSpaceAngleShifted / 2.0) * phaseY
            var sweepAngleShifted = (sliceAngle - sliceSpaceAngleShifted) * phaseY
            if (sweepAngleShifted < 0.0)
            {
                sweepAngleShifted = 0.0
            }
            
            let path = CGPathCreateMutable()
            
            CGPathMoveToPoint(
                path,
                nil,
                center.x + highlightedRadius * cos(startAngleShifted * ChartUtils.Math.FDEG2RAD),
                center.y + highlightedRadius * sin(startAngleShifted * ChartUtils.Math.FDEG2RAD))
            CGPathAddRelativeArc(
                path,
                nil,
                center.x,
                center.y,
                highlightedRadius,
                startAngleShifted * ChartUtils.Math.FDEG2RAD,
                sweepAngleShifted * ChartUtils.Math.FDEG2RAD)
            
            var sliceSpaceRadius: CGFloat = 0.0
            if accountForSliceSpacing
            {
                sliceSpaceRadius = calculateMinimumRadiusForSpacedSlice(
                    center: center,
                    radius: radius,
                    angle: sliceAngle * phaseY,
                    arcStartPointX: center.x + radius * cos(startAngleOuter * ChartUtils.Math.FDEG2RAD),
                    arcStartPointY: center.y + radius * sin(startAngleOuter * ChartUtils.Math.FDEG2RAD),
                    startAngle: startAngleOuter,
                    sweepAngle: sweepAngleOuter)
            }
            
            if drawInnerArc &&
                (innerRadius > 0.0 || accountForSliceSpacing)
            {
                if accountForSliceSpacing
                {
                    var minSpacedRadius = sliceSpaceRadius
                    if minSpacedRadius < 0.0
                    {
                        minSpacedRadius = -minSpacedRadius
                    }
                    innerRadius = min(max(innerRadius, minSpacedRadius), radius)
                }
                
                let sliceSpaceAngleInner = visibleAngleCount == 1 || innerRadius == 0.0 ?
                    0.0 :
                    sliceSpace / (ChartUtils.Math.FDEG2RAD * innerRadius)
                let startAngleInner = rotationAngle + (angle + sliceSpaceAngleInner / 2.0) * phaseY
                var sweepAngleInner = (sliceAngle - sliceSpaceAngleInner) * phaseY
                if (sweepAngleInner < 0.0)
                {
                    sweepAngleInner = 0.0
                }
                let endAngleInner = startAngleInner + sweepAngleInner
                
                CGPathAddLineToPoint(
                    path,
                    nil,
                    center.x + innerRadius * cos(endAngleInner * ChartUtils.Math.FDEG2RAD),
                    center.y + innerRadius * sin(endAngleInner * ChartUtils.Math.FDEG2RAD))
                CGPathAddRelativeArc(
                    path,
                    nil,
                    center.x,
                    center.y,
                    innerRadius,
                    endAngleInner * ChartUtils.Math.FDEG2RAD,
                    -sweepAngleInner * ChartUtils.Math.FDEG2RAD)
            }
            else
            {
                if accountForSliceSpacing
                {
                    let angleMiddle = startAngleOuter + sweepAngleOuter / 2.0
                    
                    let arcEndPointX = center.x + sliceSpaceRadius * cos(angleMiddle * ChartUtils.Math.FDEG2RAD)
                    let arcEndPointY = center.y + sliceSpaceRadius * sin(angleMiddle * ChartUtils.Math.FDEG2RAD)
                    
                    CGPathAddLineToPoint(
                        path,
                        nil,
                        arcEndPointX,
                        arcEndPointY)
                }
                else
                {
                    CGPathAddLineToPoint(
                        path,
                        nil,
                        center.x,
                        center.y)
                }
            }
            
            CGPathCloseSubpath(path)
            
            CGContextBeginPath(context)
            CGContextAddPath(context, path)
            CGContextEOFillPath(context)
        }
        
        CGContextRestoreGState(context)
    }
}
