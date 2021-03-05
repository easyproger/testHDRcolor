//
//  ViewController.swift
//  testHDR
//
//  Created by Дмитрий Савичев on 05.03.2021.
//

import UIKit
import MetalKit
import MetalPerformanceShaders

class ViewController: UIViewController {

    var metalView: TestMTK?
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let fileURL = Bundle.main.url(forResource: "IMG_0423", withExtension: "MOV") else { return }
        metalView = TestMTK(frame: .zero, device: MTLCreateSystemDefaultDevice(), url: fileURL)
        metalView?.backgroundColor = .red
        metalView!.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(metalView!)
        
        NSLayoutConstraint.activate([
            metalView!.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            metalView!.leftAnchor.constraint(equalTo: view.leftAnchor),
            metalView!.rightAnchor.constraint(equalTo: view.rightAnchor),
            metalView!.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
        ])
    }


}

