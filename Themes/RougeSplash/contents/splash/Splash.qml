/*
 *   Copyright 2014 Marco Martin <mart@kde.org>
 *
 *   This program is free software; you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License version 2,
 *   or (at your option) any later version, as published by the Free
 *   Software Foundation
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details
 *
 *   You should have received a copy of the GNU General Public
 *   License along with this program; if not, write to the
 *   Free Software Foundation, Inc.,
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
 */

import QtQuick 2.5
import QtGraphicalEffects 1.0

Image {
    id: root
    source: "images/background.png"
    fillMode: Image.PreserveAspectCrop
    
    property int stage
    
    onStageChanged: {
        if (stage == 1) {
            introAnimation.running = true
            preOpacityAnimation.from = 0;
            preOpacityAnimation.to = 1;
            preOpacityAnimation.running = true;
        }
        if (stage == 4) {
            preOpacityAnimation.from = 1;
            preOpacityAnimation.to = 0;
            preOpacityAnimation.running = true;
        
        }
    }


 
    


 

}
