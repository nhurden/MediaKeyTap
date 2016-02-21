//
//  Extensions.swift
//  Castle
//
//  Created by Nicholas Hurden on 22/02/2016.
//  Copyright © 2016 Nicholas Hurden. All rights reserved.
//

import Foundation

infix operator <^> {
    precedence 130
    associativity left
}

func <^><T, U>(f: T -> U, ap: T?) -> U? {
    return ap.map(f)
}