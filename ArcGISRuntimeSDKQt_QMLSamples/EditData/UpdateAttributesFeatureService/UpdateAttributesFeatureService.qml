// Copyright 2015 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import QtQuick 2.3
import QtQuick.Controls 1.2
import QtGraphicalEffects 1.0
import Esri.ArcGISRuntime 100.00
import Esri.ArcGISExtras 1.1

Rectangle {
    width: 800
    height: 600

    property real scaleFactor: System.displayScaleFactor
    property double mousePointX
    property double mousePointY
    property string damageType

    // Create MapView that contains a Map
    MapView {
        id: mapView
        anchors.fill: parent

        Map {
            // Set the initial basemap to Streets
            BasemapStreets { }

            // Set the initial viewpoint over the Netherlands
            initialViewpoint: ViewpointCenter {
                center: Point {
                    x: 544871.19
                    y: 6806138.66
                    spatialReference: SpatialReference { wkid: 102100 }
                }
                scale: 2e6
            }

            FeatureLayer {
                id: featureLayer

                selectionColor: "cyan"
                selectionWidth: 3 * scaleFactor

                // declare as child of feature layer, as featureTable is the default property
                ServiceFeatureTable {
                    id: featureTable
                    url: "http://sampleserver6.arcgisonline.com/arcgis/rest/services/DamageAssessment/FeatureServer/0"

                    // make sure edits are successfully applied to the service
                    onApplyEditsStatusChanged: {
                        if (applyEditsStatus === Enums.TaskStatusCompleted) {
                            console.log("successfully updated feature");
                        }
                    }

                    // signal handler for the asynchronous updateFeature method
                    onUpdateFeatureStatusChanged: {
                        if (updateFeatureStatus === Enums.TaskStatusCompleted) {
                            // apply the edits to the service
                            featureTable.applyEdits();
                        }
                    }
                }

                // signal handler for asynchronously fetching the selected feature
                onSelectedFeaturesStatusChanged: {
                    if (selectedFeaturesStatus === Enums.TaskStatusCompleted) {
                        while (selectedFeaturesResult.iterator.hasNext) {
                            // obtain the feature
                            var feat = selectedFeaturesResult.iterator.next();
                            // set the new attribute value
                            feat.setAttributeValue("typdamage", damageComboBox.currentText);
                            // update the feature in the feature table asynchronously
                            featureTable.updateFeature(feat);                            
                        }
                    }
                }                                

                // signal handler for selecting features
                onSelectFeaturesStatusChanged: {
                    if (selectFeaturesStatus === Enums.TaskStatusCompleted) {
                        if (!selectFeaturesResult.iterator.hasNext)
                            return;

                        var feat  = selectFeaturesResult.iterator.next();
                        damageType = feat.attributes["typdamage"];

                        // show the callout
                        callout.x = mousePointX;
                        callout.y = mousePointY;
                        callout.visible = true;
                    }
                }
            }
        }

        QueryParameters {
            id: params
            outFields: ["*"]
            maxFeatures: 1
        }

        // hide the callout after navigation
        onVisibleAreaChanged: {
            callout.visible = false;
            updateWindow.visible = false;
        }

        onMouseClicked: {
            // reset the map callout and update window
            featureLayer.clearSelection();
            callout.visible = false;
            updateWindow.visible = false;

            // create an envelope with some tolerance and query for feature selection within that envelope
            var tolerance = 10 * scaleFactor;
            var mapTolerance = tolerance * unitsPerPixel;
            mousePointX = mouse.x;
            mousePointY = mouse.y - callout.height;
            var envJson = {"xmin" : mouse.mapX - mapTolerance, "ymin" : mouse.mapY - mapTolerance, "xmax" : mouse.mapX + mapTolerance, "ymax" : mouse.mapY + mapTolerance,
                "spatialReference" : {"wkid": 102100}};
            var envelope = ArcGISRuntimeEnvironment.createObject("Envelope", {"json" : envJson});

            // set the envelope as the geometry for the query parameter
            params.geometry = envelope;
            // query and select the features
            featureLayer.selectFeaturesWithQuery(params, Enums.SelectionModeNew);
        }
    }

    // map callout window
    Rectangle {
        id: callout
        width: row.width + (10 * scaleFactor) // add 10 for padding
        height: 40 * scaleFactor
        radius: 5
        border {
            color: "lightgrey"
            width: .5
        }
        visible: false

        MouseArea {
            anchors.fill: parent
            onClicked: mouse.accepted = true
        }

        Row {
            id: row
            anchors {
                verticalCenter: parent.verticalCenter
                left: parent.left
                margins: 5 * scaleFactor
            }
            spacing: 10

            Text {
                text: damageType
                font.pixelSize: 18 * scaleFactor
            }

            Rectangle {
                radius: 100
                width: 22 * scaleFactor
                height: width
                color: "transparent"
                border.color: "blue"
                antialiasing: true

                Text {
                    anchors.centerIn: parent
                    text: "i"
                    font.pixelSize: 18 * scaleFactor
                    color: "blue"
                }

                // create a mouse area over the (i) text to open the update window
                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        updateWindow.visible = true;
                    }
                }
            }
        }
    }

    // Update Window
    Rectangle {
        id: updateWindow
        anchors.centerIn: parent
        width: 200 * scaleFactor
        height: 110 * scaleFactor
        radius: 10
        visible: false

        GaussianBlur {
            anchors.fill: updateWindow
            source: mapView
            radius: 40
            samples: 20
        }

        MouseArea {
            anchors.fill: parent
            onClicked: mouse.accepted = true
            onWheel: wheel.accepted = true
        }

        Column {
            anchors {
                fill: parent
                margins: 10 * scaleFactor
            }
            spacing: 10
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                Text {
                    text: "Update Attribute"
                    font.pixelSize: 16 * scaleFactor
                }
            }

            ComboBox {
                id: damageComboBox
                width: updateWindow.width - (20 * scaleFactor)
                model: ["Destroyed", "Major", "Minor", "Affected", "Inaccessible"]
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                Button {
                    width: (updateWindow.width / 2) - (20 * scaleFactor)
                    text: "Update"
                    // once the update button is clicked, hide the windows, and fetch the currently selected features
                    onClicked: {
                        callout.visible = false;
                        updateWindow.visible = false;
                        featureLayer.selectedFeatures();
                    }
                }

                Button {
                    width: (updateWindow.width / 2) - (20 * scaleFactor)
                    text: "Cancel"
                    // once the cancel button is clicked, hide the window
                    onClicked: updateWindow.visible = false;
                }
            }
        }
    }

    // neatline
    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border {
            width: 0.5 * scaleFactor
            color: "black"
        }
    }
}
