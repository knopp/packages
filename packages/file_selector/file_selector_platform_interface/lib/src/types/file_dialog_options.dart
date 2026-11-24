// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart' show immutable;

/// Configuration options for any file selector dialog.
@immutable
class FileDialogOptions {
  /// Creates a new options set with the given settings.
  const FileDialogOptions({
    this.initialDirectory,
    this.confirmButtonText,
    this.canCreateDirectories,
    this.viewId,
  });

  /// The initial directory the dialog should open with.
  final String? initialDirectory;

  /// The label for the button that confirms selection.
  final String? confirmButtonText;

  /// Whether the user is allowed to create new directories in the dialog.
  ///
  /// If null, the platform will decide the default value.
  ///
  /// May not be supported on all platforms.
  final bool? canCreateDirectories;

  /// The ID of the view to associate the dialog with.
  ///
  /// When provided on platforms that support multi-window dialogs, the dialog
  /// is presented relative to the window containing this view.
  final int? viewId;
}

/// Configuration options for a save dialog.
@immutable
class SaveDialogOptions extends FileDialogOptions {
  /// Creates a new options set with the given settings.
  const SaveDialogOptions({
    super.initialDirectory,
    super.confirmButtonText,
    super.canCreateDirectories,
    super.viewId,
    this.suggestedName,
  });

  /// The suggested name of the file to save or open.
  final String? suggestedName;
}
