//==============================================
//  MuseScore
//
//  Erhu (Niko) Notation plugin for MuseScore Ver. 2.0
// 
//  Copyright (C)2017 Yuichiro Nakata
//
//  This program is a port of the following plugin.
//  [Erhu Numbered Notation (for MuseScore Ver. 1.x)]
//  https://musescore.org/en/project/erhu
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
//==============================================

import MuseScore 1.0
import QtQuick 2.2
import QtQuick.Window 2.2
import QtQuick.Controls 1.1
import QtQuick.Layouts 1.1
import QtQuick.Dialogs 1.2
import Qt.labs.settings 1.0

MuseScore {

	menuPath: "Plugins.Erhu Notation"
	version: "1.0.00"
	description: qsTr("Erhu note names, fingering etc.")

	// ********************************************************************************
	// Properties
	// ********************************************************************************

	property var fingers : [
		"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", 
		"M", "N", "O", "P", "Q", "R", "S", "T", "U", "V", "W", "X",
		"Y", "Z", "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", 
		"m", "n", "o", "p", "q","r","s","t","u","v","x","y","z",
		"0","1","2","3","4","5","6","7","8"
	]
	property var keyValues:   [ 0, -5, -3,  2,  3,  2, -5]
	property var limitValues: [62, 62, 62, 62, 62, 60, 55]

	property var classNotation  : "erhu_notation_text"
	property var classTuning    : "erhu_tuning_text"

	// ********************************************************************************
	// Settings
	// ********************************************************************************
	Settings {
		id : settings
		category : "pluginSettings"
		property int initFontSize: 14
		property int initPosition: 11
		property int tuningIndex: 0
		property int accidentalIndex: 0
		property int fontSize: 0
		property int position: 0
	}

	// ********************************************************************************
	// Events
	// ********************************************************************************

	onRun: {
		if (!curScore) {
			Qt.quit();
		} else {
			window.visible = true;
			loadSettings()
		}
	}

	// ********************************************************************************
	// UI
	// ********************************************************************************
	property int margin: 11

	Window {
		id: window
		title: "Erhu Notation : " + curScore.name
		visible : false
		minimumWidth:  mainLayout.implicitWidth  + 2 * margin
		minimumHeight: mainLayout.implicitHeight + 2 * margin
		maximumWidth:  mainLayout.implicitWidth  + 2 * margin
		maximumHeight: mainLayout.implicitHeight + 2 * margin
		ColumnLayout {
			id: mainLayout
			anchors.fill: parent
			anchors.margins: margin

			// ======================  RADIO BUTTONS
			GroupBox {
				id: gbRadioButtons
				title: "Erhu in"
				Layout.fillWidth: true
				anchors.top: mainLayout.top
				GridLayout {
					columns: 2
					GroupBox {
						flat: true
						GridLayout {
							Layout.fillHeight: true
							columns: 2
							ExclusiveGroup { id: tuningGroup }
							Repeater {
								id: repeatTuning
								model: [ "1=D (1 5)", "1=G (5. 2.)", "1=F (6. 3)", "1=C (2 6)", "1=Bb(3 7)", "1=C (1 5)", "1=G (1 5)" ]
								RadioButton { text: modelData; exclusiveGroup: tuningGroup; checked: (index==0) }
							}
						}
					}
					GroupBox {
						flat: true
						Layout.fillHeight: true
						ColumnLayout {
							ExclusiveGroup { id: accidentalGroup }
							Repeater {
								id: repeatAccidental; model: ["#", "b"]
								RadioButton { text: modelData; exclusiveGroup: accidentalGroup; checked: (index==0) }
							}
						}
					}
				}
			}

			// ======================  ADJUSTMENTS
			GroupBox {
				title: "Adjustments"
				Layout.fillWidth: true
				anchors.top: gbRadioButtons.bottom
				GridLayout {
					anchors.fill: parent
					columns: 2
					Label { text: "Font Size" }
					SpinBox {
						id: valFontSize; Layout.fillWidth: true
						minimumValue: 8; maximumValue: 32; value: settings.initFontSize
					}

					Label { text: "Vertical Position" }
					SpinBox {
						id: valPosition; Layout.fillWidth: true
						minimumValue: -20; maximumValue: 20; value: settings.initPosition
					}
				}
			}

			// ======================  BUTTONS
			GridLayout {
				anchors.left: parent.left
				anchors.right: parent.right
				columns: 2
				RowLayout {
					Button { id: defaultButton; text: "Default";
						onClicked: {
							settings.tuningIndex = 0
							settings.accidentalIndex = 0
							settings.fontSize = settings.initFontSize
							settings.position = settings.initPosition
							loadSettings()
						}
					}
					Button { id: debugButton; text: "Debug";  onClicked: { debug() }
						visible: false // Experimental function
					}
					Button { id: clearButton; text: "Clear"; onClicked: { dlgClearOptions.open() }
						visible: false // Experimental function
					}
				}
				RowLayout {
					anchors.right: parent.right
					Button { id: closeButton; text: "Cancel"; onClicked: { window.close(); Qt.quit() } }
					Button { id: okButton;    text: "OK";     onClicked: { window.close(); apply(); saveSettings(); Qt.quit() } }
				}
			}
		}

		// ======================  CLEAR OPTIONS DIALOG
		Dialog {
			id: dlgClearOptions
			visible: false
			modality: Qt.WindowModal
			title: "Options"
			standardButtons: StandardButton.Ok | StandardButton.Cancel
			onRejected: { dlgClearOptions.close(); }
			onAccepted: { dlgClearOptions.close(); clear(); Qt.quit() }
			Column {
				id: dialogLayout
				CheckBox { id: cbClearTuningMark; text: "Clear tuning mark" }
				CheckBox { id: cbClearNotations;  text: "Clear number notations"; checked: true }
			}
		}
	}

	// ********************************************************************************
	// Main Function
	// ********************************************************************************

	// ------------------------------------------------------------
	// [Summary]
	//   Apply to the score or the selection
	// ------------------------------------------------------------
	function apply() {
		curScore.startCmd()
		addNotations()
		curScore.endCmd()
	}

	// ------------------------------------------------------------
	// [Summary]
	//   !This is under experiment!
	//   Clear the tuning mark and the all notations
	// ------------------------------------------------------------
	function clear() {
		curScore.startCmd()
		if (cbClearNotations.checked)  { clearAllNotations() }
		if (cbClearTuningMark.checked) { clearTuningMark() }
		curScore.endCmd()
	}

	function debug() {
	}

	// ********************************************************************************
	// Functions
	// ********************************************************************************

	// ------------------------------------------------------------
	// [Summary]
	//   Add notations to selection or current score
	// ------------------------------------------------------------
	function addNotations() {
		var key = keyValues[getRadioSelectedIndex(repeatTuning)]
		var limit = limitValues[getRadioSelectedIndex(repeatTuning)]
		var yPos = valPosition.value
		var xPos = 0

		eachChords(
			false,
			function(chord, cursor) {
				// create a notation text
				var text = newElement(Element.STAFF_TEXT)
				var notes = cursor.element.notes

				for (var note = 0; note < notes.length; note++) {
					var pitch = notes[note].pitch;
					var index = pitch -50 +1 +key;

					if(pitch >= limit && index < fingers.length-1){
						text.text += fingers[index]+"\n"
					}
				}

				text.text =
					"<span class=\"" + classNotation + "\">" +
					"<font face=\"" + ( repeatAccidental.itemAt(0).checked ? "ErhuS" : "ErhuF" ) +
					"\" size=\"" + valFontSize.value + "\">" +
					text.text +
					"</font></span>"
				text.pos.x = xPos
				text.pos.y = yPos
				cursor.add(text)
			},
			function(index) {
				// create a tuning text
				var cursor = curScore.newCursor()
				cursor.voice = 0
				cursor.staff = index
				cursor.rewind(0)
				var text = newElement(Element.TEMPO_TEXT)
				text.pos.x = -4
				text.pos.y = -1
				text.text = "<span class=\"" + classTuning + "\">"  + tuningGroup.current.text + "</span>"
				cursor.add(text)
			}
		)
	}

	// ------------------------------------------------------------
	// [Summary]
	//   !This is under experiment!
	//   Clear all of the number notations
	// ------------------------------------------------------------
	function clearAllNotations() {
		eachChords(
			true,
			function(chord, cursor) {
				for (var i = 0; i < cursor.segment.annotations.length; i++) {
					var element = cursor.segment.annotations[i]
					if (element && element.type == Element.STAFF_TEXT
						&& 0 <= element.text.indexOf(classNotation)) {
						//cursor.remove(element)
						//cursor.element.remove(element.element)
						console.log(Object.keys(Cursor))
						//console.log(Object.keys(element))
						break;
					}
				}
			}
		)
	}

	// ------------------------------------------------------------
	// [Summary]
	//   !This is under experiment!
	//   Clear the tuning mark
	// ------------------------------------------------------------
	function clearTuningMark() {
	}

	// ------------------------------------------------------------
	// [Summary]
	//   Returns index of selected radio button
	// [Arguments]
	//   repeat: Repeat component
	// [Return]
	//   index
	// ------------------------------------------------------------
	function getRadioSelectedIndex(repeat) {
		for (var i=0; i<repeat.count; i++) {
			if (repeat.itemAt(i).checked) { return i; }
		}
		return 0;
	}

	// ------------------------------------------------------------
	// [Summary]
	//   Repeat each chord
	// [Arguments]
	//   isFullScore: true = each full, false = each selection
	//   onChord    : callback function on find each chord
	//                args (chordElement, currentCursor)
	//   onstaff    : callback function on start of each staff
	//                args (staffIndex, currentCursor)
	// ------------------------------------------------------------
	function eachChords(isFullScore, onChord, onStaff) {
		var cursor = curScore.newCursor()

		cursor.rewind(1) // goto selection start
		var startStaff = cursor.staffIdx
		cursor.rewind(2) // goto selection end
		var endStaff = cursor.staffIdx
		var endTick  = (cursor.tick == 0) ? curScore.lastSegment.tick + 1 : cursor.tick
		if (isFullScore || !cursor.segment) { // no selection
			startStaff = 0
			endStaff = curScore.nstaves - 1
		}
		for (var staff=0; staff<=endStaff; staff++) {
			if (onStaff) { onStaff(staff, cursor) }
			cursor.rewind(1)
			cursor.voise = 0
			cursor.staff = staff
			if (isFullScore || !cursor.segment) { cursor.rewind(0) }
			while (cursor.segment && (isFullScore || cursor.tick < endTick)) {
				if (cursor.element && cursor.element.type == Element.CHORD) {
					if (onChord) { onChord(cursor.element, cursor) }
				}
				cursor.next()
			}
		}
	}

	// ------------------------------------------------------------
	// [Summary]
	//   Save the plugin settings
	// ------------------------------------------------------------
	function saveSettings() {
		settings.tuningIndex = getRadioSelectedIndex(repeatTuning)
		settings.accidentalIndex = getRadioSelectedIndex(repeatAccidental)
		settings.fontSize = valFontSize.value
		settings.position = valPosition.value
	}

	// ------------------------------------------------------------
	// [Summary]
	//   Load the plugin settings
	// ------------------------------------------------------------
	function loadSettings() {
		repeatTuning.itemAt(settings.tuningIndex).checked = true
		repeatAccidental.itemAt(settings.accidentalIndex).checked = true
		valFontSize.value = (settings.fontSize == 0) ? settings.initFontSize : settings.fontSize
		valPosition.value = (settings.position == 0) ? settings.initPosition : settings.position
	}

} // end MuseScore
