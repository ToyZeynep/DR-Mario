//
//  TouchInputHandler.swift
//  DR. Mario
//
//  Port of com.rummuscan.game.TouchInputHandler.
//
//  Basılı tutunca tekrar hareket (DAS/ARR) mantığını yönetir.
//  Hem klavye hem dokunmatik buton kaynaklı input bu sınıfa "held" bilgisi
//  olarak bildirilir; asıl tekrar zamanlaması burada, engine tick'inden
//  bağımsız olarak update(delta:) ile ilerler.
//

import Foundation

final class TouchInputHandler {
    private static let dasDelay: Double = 0.18   // ilk basıştan sonraki bekleme
    private static let dasRepeat: Double = 0.06  // basılı tutunca tekrar aralığı

    private let engine: GameEngine

    private var leftHeld = false, rightHeld = false, downHeld = false
    private var leftTimer: Double = 0, rightTimer: Double = 0, downTimer: Double = 0

    init(engine: GameEngine) {
        self.engine = engine
    }

    func setLeftHeld(_ held: Bool) {
        if held && !leftHeld {
            engine.moveLeft()
            leftTimer = 0
        }
        if !held { leftTimer = 0 }
        leftHeld = held
    }

    func setRightHeld(_ held: Bool) {
        if held && !rightHeld {
            engine.moveRight()
            rightTimer = 0
        }
        if !held { rightTimer = 0 }
        rightHeld = held
    }

    func setDownHeld(_ held: Bool) {
        if !held { downTimer = 0 }
        downHeld = held
    }

    func triggerRotateCW() { engine.rotateCW() }
    func triggerRotateCCW() { engine.rotateCCW() }
    func triggerHardDrop() { engine.hardDrop() }

    /// Her render frame'inde çağrılmalı (gerçek delta ile, fixed tick ile değil).
    func update(delta: Double) {
        if leftHeld {
            leftTimer += delta
            if leftTimer >= TouchInputHandler.dasDelay {
                leftTimer -= TouchInputHandler.dasRepeat
                engine.moveLeft()
            }
        }
        if rightHeld {
            rightTimer += delta
            if rightTimer >= TouchInputHandler.dasDelay {
                rightTimer -= TouchInputHandler.dasRepeat
                engine.moveRight()
            }
        }
        if downHeld {
            downTimer += delta
            if downTimer >= TouchInputHandler.dasRepeat {
                downTimer = 0
                engine.softDrop()
            }
        }
    }
}
