// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import FlutterMacOS
import Testing
import UniformTypeIdentifiers

@testable import file_selector_macos

class TestPanelController: NSObject, PanelController {
  // The last panels that the relevant display methods were called on.
  public var savePanel: NSSavePanel?
  public var openPanel: NSOpenPanel?
  public var lastWindow: NSWindow?

  // Mock return values for the display methods.
  public var saveURL: URL?
  public var openURLs: [URL]?

  func display(
    _ panel: NSSavePanel, for window: NSWindow?, completionHandler handler: @escaping (URL?) -> Void
  ) {
    savePanel = panel
    lastWindow = window
    handler(saveURL)
  }

  func display(
    _ panel: NSOpenPanel, for window: NSWindow?,
    completionHandler handler: @escaping ([URL]?) -> Void
  ) {
    openPanel = panel
    lastWindow = window
    handler(openURLs)
  }
}

class TestViewProvider: NSObject, ViewProvider {
  var window: NSWindow? = NSWindow()
  var windowsByViewId: [Int64: NSWindow] = [:]

  func view(forIdentifier viewId: Int64?) -> ViewLookupResult {
    guard let viewId = viewId else {
      return .view(window?.contentView)
    }
    guard let targetWindow = windowsByViewId[viewId] else {
      return .notFound
    }
    return .view(targetWindow.contentView)
  }
}

private class LegacyRegistrarStub: NSObject {}

private class MultiViewRegistrarStub: NSObject {
  var viewsById: [Int64: NSView] = [:]

  @objc(viewForIdentifier:)
  func view(forIdentifier viewIdentifier: Int64) -> NSView? {
    return viewsById[viewIdentifier]
  }
}

@Suite @MainActor struct ExampleTests {

  @Test func openSimple() async throws {
    let panelController = TestPanelController()
    let plugin = FileSelectorPlugin(
      viewProvider: TestViewProvider(),
      panelController: panelController)

    let returnPath = "/foo/bar"
    panelController.openURLs = [URL(fileURLWithPath: returnPath)]

    await confirmation("completion") { called in
      let options = OpenPanelOptions(
        allowsMultipleSelection: false,
        canChooseDirectories: false,
        canChooseFiles: true,
        baseOptions: SavePanelOptions())
      plugin.displayOpenPanel(options: options) { result in
        switch result {
        case .success(let paths):
          #expect(paths == [returnPath])
        case .failure(let error):
          Issue.record("\(error)")
        }
        called()
      }
    }

    let panel = try #require(panelController.openPanel)
    #expect(panel.canChooseFiles)
    // For consistency across platforms, directory selection is disabled.
    #expect(!panel.canChooseDirectories)
  }

  @Test func openWithArguments() async throws {
    let panelController = TestPanelController()
    let plugin = FileSelectorPlugin(
      viewProvider: TestViewProvider(),
      panelController: panelController)

    let returnPath = "/foo/bar"
    panelController.openURLs = [URL(fileURLWithPath: returnPath)]

    await confirmation("completion") { called in
      let options = OpenPanelOptions(
        allowsMultipleSelection: false,
        canChooseDirectories: false,
        canChooseFiles: true,
        baseOptions: SavePanelOptions(
          directoryPath: "/some/dir",
          nameFieldStringValue: "a name",
          prompt: "Open it!"))
      plugin.displayOpenPanel(options: options) { result in
        switch result {
        case .success(let paths):
          #expect(paths == [returnPath])
        case .failure(let error):
          Issue.record("\(error)")
        }
        called()
      }
    }

    let panel = try #require(panelController.openPanel)
    #expect(panel.directoryURL?.path == "/some/dir")
    // nameFieldStringValue is not set for NSOpenPanel, only for NSSavePanel
    #expect(panel.nameFieldStringValue != "a name")
    #expect(panel.prompt == "Open it!")
  }

  @Test func openMultiple() async throws {
    let panelController = TestPanelController()
    let plugin = FileSelectorPlugin(
      viewProvider: TestViewProvider(),
      panelController: panelController)

    let returnPaths = ["/foo/bar", "/foo/baz"]
    panelController.openURLs = returnPaths.map({ path in URL(fileURLWithPath: path) })

    await confirmation("completion") { called in
      let options = OpenPanelOptions(
        allowsMultipleSelection: true,
        canChooseDirectories: false,
        canChooseFiles: true,
        baseOptions: SavePanelOptions())
      plugin.displayOpenPanel(options: options) { result in
        switch result {
        case .success(let paths):
          #expect(paths == returnPaths)
        case .failure(let error):
          Issue.record("\(error)")
        }
        called()
      }
    }

    _ = try #require(panelController.openPanel)
  }

  @Test func openWithFilter() async throws {
    let panelController = TestPanelController()
    let plugin = FileSelectorPlugin(
      viewProvider: TestViewProvider(),
      panelController: panelController)

    let returnPath = "/foo/bar"
    panelController.openURLs = [URL(fileURLWithPath: returnPath)]

    await confirmation("completion") { called in
      let options = OpenPanelOptions(
        allowsMultipleSelection: true,
        canChooseDirectories: false,
        canChooseFiles: true,
        baseOptions: SavePanelOptions(
          allowedFileTypes: AllowedTypes(
            extensions: ["txt", "json"],
            mimeTypes: ["text/html"],
            utis: ["public.text", "public.image"])))
      plugin.displayOpenPanel(options: options) { result in
        switch result {
        case .success(let paths):
          #expect(paths == [returnPath])
        case .failure(let error):
          Issue.record("\(error)")
        }
        called()
      }
    }

    let panel = try #require(panelController.openPanel)
    #expect(panel.allowedContentTypes.contains(UTType.plainText))
    #expect(panel.allowedContentTypes.contains(UTType.json))
    #expect(panel.allowedContentTypes.contains(UTType.html))
    #expect(panel.allowedContentTypes.contains(UTType.image))
  }

  @Test func filterUnknownFileExtension() async throws {
    let panelController = TestPanelController()
    let plugin = FileSelectorPlugin(
      viewProvider: TestViewProvider(),
      panelController: panelController)

    let unknownExtension = "somenewextension"
    let returnPath = "/foo/bar"
    panelController.openURLs = [URL(fileURLWithPath: returnPath)]

    await confirmation("completion") { called in
      let options = OpenPanelOptions(
        allowsMultipleSelection: true,
        canChooseDirectories: false,
        canChooseFiles: true,
        baseOptions: SavePanelOptions(
          allowedFileTypes: AllowedTypes(
            extensions: [unknownExtension],
            mimeTypes: [],
            utis: [])))
      plugin.displayOpenPanel(options: options) { result in
        switch result {
        case .success(let paths):
          #expect(paths == [returnPath])
        case .failure(let error):
          Issue.record("\(error)")
        }
        called()
      }
    }

    let panel = try #require(panelController.openPanel)
    #expect(panel.allowedContentTypes.count == 1)
    let allowedType = try #require(panel.allowedContentTypes.first)
    #expect(allowedType.preferredFilenameExtension == unknownExtension)
    // If this isn't true, the dynamic type created for the extension won't work as a file
    // extension filter.
    #expect(allowedType.conforms(to: UTType.data))
  }

  @Test func openCancel() async throws {
    let panelController = TestPanelController()
    let plugin = FileSelectorPlugin(
      viewProvider: TestViewProvider(),
      panelController: panelController)

    await confirmation("completion") { called in
      let options = OpenPanelOptions(
        allowsMultipleSelection: false,
        canChooseDirectories: false,
        canChooseFiles: true,
        baseOptions: SavePanelOptions())
      plugin.displayOpenPanel(options: options) { result in
        switch result {
        case .success(let paths):
          #expect(paths.isEmpty)
        case .failure(let error):
          Issue.record("\(error)")
        }
        called()
      }
    }

    _ = try #require(panelController.openPanel)
  }

  @Test func saveSimple() async throws {
    let panelController = TestPanelController()
    let plugin = FileSelectorPlugin(
      viewProvider: TestViewProvider(),
      panelController: panelController)

    let returnPath = "/foo/bar"
    panelController.saveURL = URL(fileURLWithPath: returnPath)

    await confirmation("completion") { called in
      let options = SavePanelOptions()
      plugin.displaySavePanel(options: options) { result in
        switch result {
        case .success(let path):
          #expect(path == returnPath)
        case .failure(let error):
          Issue.record("\(error)")
        }
        called()
      }
    }

    let panel = try #require(panelController.savePanel)
    // By default, "New Folder" button is visible for Save dialogs
    #expect(panel.canCreateDirectories)
  }

  @Test func saveWithArguments() async throws {
    let panelController = TestPanelController()
    let plugin = FileSelectorPlugin(
      viewProvider: TestViewProvider(),
      panelController: panelController)

    let returnPath = "/foo/bar"
    panelController.saveURL = URL(fileURLWithPath: returnPath)

    await confirmation("completion") { called in
      let options = SavePanelOptions(
        directoryPath: "/some/dir",
        nameFieldStringValue: "a name",
        prompt: "Save it!")
      plugin.displaySavePanel(options: options) { result in
        switch result {
        case .success(let path):
          #expect(path == returnPath)
        case .failure(let error):
          Issue.record("\(error)")
        }
        called()
      }
    }

    let panel = try #require(panelController.savePanel)
    #expect(panel.directoryURL?.path == "/some/dir")
    #expect(panel.nameFieldStringValue == "a name")
    #expect(panel.prompt == "Save it!")
  }

  @Test func saveNewFolderHidden() async throws {
    let panelController = TestPanelController()
    let plugin = FileSelectorPlugin(
      viewProvider: TestViewProvider(),
      panelController: panelController)

    let returnPath = "/foo/bar"
    panelController.saveURL = URL(fileURLWithPath: returnPath)

    await confirmation("completion") { called in
      let options = SavePanelOptions(canCreateDirectories: false)
      plugin.displaySavePanel(options: options) { result in
        switch result {
        case .success(let path):
          #expect(path == returnPath)
        case .failure(let error):
          Issue.record("\(error)")
        }
        called()
      }
    }

    let panel = try #require(panelController.savePanel)
    #expect(!panel.canCreateDirectories)
  }

  @Test func saveCancel() async throws {
    let panelController = TestPanelController()
    let plugin = FileSelectorPlugin(
      viewProvider: TestViewProvider(),
      panelController: panelController)

    await confirmation("completion") { called in
      let options = SavePanelOptions()
      plugin.displaySavePanel(options: options) { result in
        switch result {
        case .success(let path):
          #expect(path == nil)
        case .failure(let error):
          Issue.record("\(error)")
        }
        called()
      }
    }

    _ = try #require(panelController.savePanel)
  }

  @Test func getDirectorySimple() async throws {
    let panelController = TestPanelController()
    let plugin = FileSelectorPlugin(
      viewProvider: TestViewProvider(),
      panelController: panelController)

    let returnPath = "/foo/bar"
    panelController.openURLs = [URL(fileURLWithPath: returnPath)]

    await confirmation("completion") { called in
      let options = OpenPanelOptions(
        allowsMultipleSelection: false,
        canChooseDirectories: true,
        canChooseFiles: false,
        baseOptions: SavePanelOptions())
      plugin.displayOpenPanel(options: options) { result in
        switch result {
        case .success(let paths):
          #expect(paths == [returnPath])
        case .failure(let error):
          Issue.record("\(error)")
        }
        called()
      }
    }

    let panel = try #require(panelController.openPanel)
    #expect(panel.canChooseDirectories)
    // For consistency across platforms, file selection is disabled.
    #expect(!panel.canChooseFiles)
    // The Dart API only allows a single directory to be returned, so users shouldn't be allowed
    // to select multiple.
    #expect(!panel.allowsMultipleSelection)
    // By default, "New Folder" button is hidden for Choose Directory dialogs.
    #expect(!panel.canCreateDirectories)
  }

  @Test func getDirectoryCancel() async throws {
    let panelController = TestPanelController()
    let plugin = FileSelectorPlugin(
      viewProvider: TestViewProvider(),
      panelController: panelController)

    await confirmation("completion") { called in
      let options = OpenPanelOptions(
        allowsMultipleSelection: false,
        canChooseDirectories: true,
        canChooseFiles: false,
        baseOptions: SavePanelOptions())
      plugin.displayOpenPanel(options: options) { result in
        switch result {
        case .success(let paths):
          #expect(paths.isEmpty)
        case .failure(let error):
          Issue.record("\(error)")
        }
        called()
      }
    }

    _ = try #require(panelController.openPanel)
  }

  @Test func getDirectoriesMultiple() async throws {
    let panelController = TestPanelController()
    let plugin = FileSelectorPlugin(
      viewProvider: TestViewProvider(),
      panelController: panelController)

    let returnPaths = ["/foo/bar", "/foo/test"]
    panelController.openURLs = returnPaths.map({ path in URL(fileURLWithPath: path) })

    await confirmation("completion") { called in
      let options = OpenPanelOptions(
        allowsMultipleSelection: true,
        canChooseDirectories: true,
        canChooseFiles: false,
        baseOptions: SavePanelOptions())
      plugin.displayOpenPanel(options: options) { result in
        switch result {
        case .success(let paths):
          #expect(paths == returnPaths)
        case .failure(let error):
          Issue.record("\(error)")
        }
        called()
      }
    }

    let panel = try #require(panelController.openPanel)
    #expect(panel.canChooseDirectories)
    // For consistency across platforms, file selection is disabled.
    #expect(!panel.canChooseFiles)
    #expect(panel.allowsMultipleSelection)
    // By default, "New Folder" button is hidden for Choose Directory dialogs.
    #expect(!panel.canCreateDirectories)
  }

  @Test func getDirectoryMultipleCancel() async throws {
    let panelController = TestPanelController()
    let plugin = FileSelectorPlugin(
      viewProvider: TestViewProvider(),
      panelController: panelController)

    await confirmation("completion") { called in
      let options = OpenPanelOptions(
        allowsMultipleSelection: true,
        canChooseDirectories: true,
        canChooseFiles: false,
        baseOptions: SavePanelOptions())
      plugin.displayOpenPanel(options: options) { result in
        switch result {
        case .success(let paths):
          #expect(paths.isEmpty)
        case .failure(let error):
          Issue.record("\(error)")
        }
        called()
      }
    }

    _ = try #require(panelController.openPanel)
  }

  @Test func getDirectoryNewFolderVisible() async throws {
    let panelController = TestPanelController()
    let plugin = FileSelectorPlugin(
      viewProvider: TestViewProvider(),
      panelController: panelController)

    let returnPath = "/foo/bar"
    panelController.openURLs = [URL(fileURLWithPath: returnPath)]

    await confirmation("completion") { called in
      let options = OpenPanelOptions(
        allowsMultipleSelection: false,
        canChooseDirectories: true,
        canChooseFiles: false,
        baseOptions: SavePanelOptions(canCreateDirectories: true))

      plugin.displayOpenPanel(options: options) { result in
        switch result {
        case .success(let paths):
          #expect(paths == [returnPath])
        case .failure(let error):
          Issue.record("\(error)")
        }
        called()
      }
    }

    let panel = try #require(panelController.openPanel)
    #expect(panel.canCreateDirectories)
  }

  @Test func openWithViewId() async throws {
    let panelController = TestPanelController()
    let viewProvider = TestViewProvider()
    let targetWindow = NSWindow()
    viewProvider.windowsByViewId[42] = targetWindow
    let plugin = FileSelectorPlugin(
      viewProvider: viewProvider,
      panelController: panelController)

    let returnPath = "/foo/bar"
    panelController.openURLs = [URL(fileURLWithPath: returnPath)]

    await confirmation("completion") { called in
      let options = OpenPanelOptions(
        allowsMultipleSelection: false,
        canChooseDirectories: false,
        canChooseFiles: true,
        baseOptions: SavePanelOptions(viewId: 42))
      plugin.displayOpenPanel(options: options) { result in
        switch result {
        case .success(let paths):
          #expect(paths == [returnPath])
        case .failure(let error):
          Issue.record("\(error)")
        }
        called()
      }
    }

    #expect(panelController.lastWindow === targetWindow)
  }

  @Test func openWithInvalidViewId() async throws {
    let panelController = TestPanelController()
    let plugin = FileSelectorPlugin(
      viewProvider: TestViewProvider(),
      panelController: panelController)

    await confirmation("completion") { called in
      let options = OpenPanelOptions(
        allowsMultipleSelection: false,
        canChooseDirectories: false,
        canChooseFiles: true,
        baseOptions: SavePanelOptions(viewId: 999))
      plugin.displayOpenPanel(options: options) { result in
        switch result {
        case .success:
          Issue.record("Expected error for invalid viewId")
        case .failure(let error):
          let pigeonError = error as? PigeonError
          #expect(pigeonError?.code == "invalid_view_id")
        }
        called()
      }
    }

    #expect(panelController.openPanel == nil)
  }

  @Test func saveWithViewId() async throws {
    let panelController = TestPanelController()
    let viewProvider = TestViewProvider()
    let targetWindow = NSWindow()
    viewProvider.windowsByViewId[42] = targetWindow
    let plugin = FileSelectorPlugin(
      viewProvider: viewProvider,
      panelController: panelController)

    let returnPath = "/foo/bar"
    panelController.saveURL = URL(fileURLWithPath: returnPath)

    await confirmation("completion") { called in
      let options = SavePanelOptions(viewId: 42)
      plugin.displaySavePanel(options: options) { result in
        switch result {
        case .success(let path):
          #expect(path == returnPath)
        case .failure(let error):
          Issue.record("\(error)")
        }
        called()
      }
    }

    #expect(panelController.lastWindow === targetWindow)
  }

  @Test func saveWithInvalidViewId() async throws {
    let panelController = TestPanelController()
    let plugin = FileSelectorPlugin(
      viewProvider: TestViewProvider(),
      panelController: panelController)

    await confirmation("completion") { called in
      let options = SavePanelOptions(viewId: 999)
      plugin.displaySavePanel(options: options) { result in
        switch result {
        case .success:
          Issue.record("Expected error for invalid viewId")
        case .failure(let error):
          let pigeonError = error as? PigeonError
          #expect(pigeonError?.code == "invalid_view_id")
        }
        called()
      }
    }

    #expect(panelController.savePanel == nil)
  }

  @Test func defaultViewProviderFallsBackWhenMultiViewSelectorMissing() {
    let defaultView = NSView()
    let provider = DefaultViewProvider(
      registrarObject: LegacyRegistrarStub(),
      defaultViewProvider: { defaultView })

    switch provider.view(forIdentifier: 42) {
    case .view(let resolved):
      #expect(resolved === defaultView)
    case .notFound:
      Issue.record("Expected fallback to default view when selector is unavailable")
    }
  }

  @Test func defaultViewProviderResolvesMultiViewSelector() {
    let defaultView = NSView()
    let secondaryView = NSView()
    let registrar = MultiViewRegistrarStub()
    registrar.viewsById[42] = secondaryView
    let provider = DefaultViewProvider(
      registrarObject: registrar,
      defaultViewProvider: { defaultView })

    switch provider.view(forIdentifier: nil) {
    case .view(let resolved):
      #expect(resolved === defaultView)
    case .notFound:
      Issue.record("Expected default view when viewId is nil")
    }

    switch provider.view(forIdentifier: 42) {
    case .view(let resolved):
      #expect(resolved === secondaryView)
    case .notFound:
      Issue.record("Expected secondary view for viewId 42")
    }

    switch provider.view(forIdentifier: 99) {
    case .view:
      Issue.record("Expected .notFound for unknown viewId 99")
    case .notFound:
      break
    }
  }
}
