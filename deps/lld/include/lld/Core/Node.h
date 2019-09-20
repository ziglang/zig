//===- lld/Core/Node.h - Input file class -----------------------*- C++ -*-===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// \file
///
/// The classes in this file represents inputs to the linker.
///
//===----------------------------------------------------------------------===//

#ifndef LLD_CORE_NODE_H
#define LLD_CORE_NODE_H

#include "lld/Core/File.h"
#include <algorithm>
#include <memory>

namespace lld {

// A Node represents a FileNode or other type of Node. In the latter case,
// the node contains meta information about the input file list.
// Currently only GroupEnd node is defined as a meta node.
class Node {
public:
  enum class Kind { File, GroupEnd };

  explicit Node(Kind type) : _kind(type) {}
  virtual ~Node() = default;

  virtual Kind kind() const { return _kind; }

private:
  Kind _kind;
};

// This is a marker for --end-group. getSize() returns the number of
// files between the corresponding --start-group and this marker.
class GroupEnd : public Node {
public:
  explicit GroupEnd(int size) : Node(Kind::GroupEnd), _size(size) {}

  int getSize() const { return _size; }

  static bool classof(const Node *a) {
    return a->kind() == Kind::GroupEnd;
  }

private:
  int _size;
};

// A container of File.
class FileNode : public Node {
public:
  explicit FileNode(std::unique_ptr<File> f)
      : Node(Node::Kind::File), _file(std::move(f)) {}

  static bool classof(const Node *a) {
    return a->kind() == Node::Kind::File;
  }

  File *getFile() { return _file.get(); }

protected:
  std::unique_ptr<File> _file;
};

} // end namespace lld

#endif // LLD_CORE_NODE_H
