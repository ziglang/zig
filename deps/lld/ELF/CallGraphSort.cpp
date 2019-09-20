//===- CallGraphSort.cpp --------------------------------------------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
///
/// Implementation of Call-Chain Clustering from: Optimizing Function Placement
/// for Large-Scale Data-Center Applications
/// https://research.fb.com/wp-content/uploads/2017/01/cgo2017-hfsort-final1.pdf
///
/// The goal of this algorithm is to improve runtime performance of the final
/// executable by arranging code sections such that page table and i-cache
/// misses are minimized.
///
/// Definitions:
/// * Cluster
///   * An ordered list of input sections which are layed out as a unit. At the
///     beginning of the algorithm each input section has its own cluster and
///     the weight of the cluster is the sum of the weight of all incomming
///     edges.
/// * Call-Chain Clustering (C³) Heuristic
///   * Defines when and how clusters are combined. Pick the highest weighted
///     input section then add it to its most likely predecessor if it wouldn't
///     penalize it too much.
/// * Density
///   * The weight of the cluster divided by the size of the cluster. This is a
///     proxy for the ammount of execution time spent per byte of the cluster.
///
/// It does so given a call graph profile by the following:
/// * Build a weighted call graph from the call graph profile
/// * Sort input sections by weight
/// * For each input section starting with the highest weight
///   * Find its most likely predecessor cluster
///   * Check if the combined cluster would be too large, or would have too low
///     a density.
///   * If not, then combine the clusters.
/// * Sort non-empty clusters by density
///
//===----------------------------------------------------------------------===//

#include "CallGraphSort.h"
#include "OutputSections.h"
#include "SymbolTable.h"
#include "Symbols.h"

using namespace llvm;
using namespace lld;
using namespace lld::elf;

namespace {
struct Edge {
  int from;
  uint64_t weight;
};

struct Cluster {
  Cluster(int sec, size_t s) : sections{sec}, size(s) {}

  double getDensity() const {
    if (size == 0)
      return 0;
    return double(weight) / double(size);
  }

  std::vector<int> sections;
  size_t size = 0;
  uint64_t weight = 0;
  uint64_t initialWeight = 0;
  Edge bestPred = {-1, 0};
};

class CallGraphSort {
public:
  CallGraphSort();

  DenseMap<const InputSectionBase *, int> run();

private:
  std::vector<Cluster> clusters;
  std::vector<const InputSectionBase *> sections;

  void groupClusters();
};

// Maximum ammount the combined cluster density can be worse than the original
// cluster to consider merging.
constexpr int MAX_DENSITY_DEGRADATION = 8;

// Maximum cluster size in bytes.
constexpr uint64_t MAX_CLUSTER_SIZE = 1024 * 1024;
} // end anonymous namespace

using SectionPair =
    std::pair<const InputSectionBase *, const InputSectionBase *>;

// Take the edge list in Config->CallGraphProfile, resolve symbol names to
// Symbols, and generate a graph between InputSections with the provided
// weights.
CallGraphSort::CallGraphSort() {
  MapVector<SectionPair, uint64_t> &profile = config->callGraphProfile;
  DenseMap<const InputSectionBase *, int> secToCluster;

  auto getOrCreateNode = [&](const InputSectionBase *isec) -> int {
    auto res = secToCluster.insert(std::make_pair(isec, clusters.size()));
    if (res.second) {
      sections.push_back(isec);
      clusters.emplace_back(clusters.size(), isec->getSize());
    }
    return res.first->second;
  };

  // Create the graph.
  for (std::pair<SectionPair, uint64_t> &c : profile) {
    const auto *fromSB = cast<InputSectionBase>(c.first.first->repl);
    const auto *toSB = cast<InputSectionBase>(c.first.second->repl);
    uint64_t weight = c.second;

    // Ignore edges between input sections belonging to different output
    // sections.  This is done because otherwise we would end up with clusters
    // containing input sections that can't actually be placed adjacently in the
    // output.  This messes with the cluster size and density calculations.  We
    // would also end up moving input sections in other output sections without
    // moving them closer to what calls them.
    if (fromSB->getOutputSection() != toSB->getOutputSection())
      continue;

    int from = getOrCreateNode(fromSB);
    int to = getOrCreateNode(toSB);

    clusters[to].weight += weight;

    if (from == to)
      continue;

    // Remember the best edge.
    Cluster &toC = clusters[to];
    if (toC.bestPred.from == -1 || toC.bestPred.weight < weight) {
      toC.bestPred.from = from;
      toC.bestPred.weight = weight;
    }
  }
  for (Cluster &c : clusters)
    c.initialWeight = c.weight;
}

// It's bad to merge clusters which would degrade the density too much.
static bool isNewDensityBad(Cluster &a, Cluster &b) {
  double newDensity = double(a.weight + b.weight) / double(a.size + b.size);
  return newDensity < a.getDensity() / MAX_DENSITY_DEGRADATION;
}

static void mergeClusters(Cluster &into, Cluster &from) {
  into.sections.insert(into.sections.end(), from.sections.begin(),
                       from.sections.end());
  into.size += from.size;
  into.weight += from.weight;
  from.sections.clear();
  from.size = 0;
  from.weight = 0;
}

// Group InputSections into clusters using the Call-Chain Clustering heuristic
// then sort the clusters by density.
void CallGraphSort::groupClusters() {
  std::vector<int> sortedSecs(clusters.size());
  std::vector<Cluster *> secToCluster(clusters.size());

  for (size_t i = 0; i < clusters.size(); ++i) {
    sortedSecs[i] = i;
    secToCluster[i] = &clusters[i];
  }

  llvm::stable_sort(sortedSecs, [&](int a, int b) {
    return clusters[a].getDensity() > clusters[b].getDensity();
  });

  for (int si : sortedSecs) {
    // clusters[si] is the same as secToClusters[si] here because it has not
    // been merged into another cluster yet.
    Cluster &c = clusters[si];

    // Don't consider merging if the edge is unlikely.
    if (c.bestPred.from == -1 || c.bestPred.weight * 10 <= c.initialWeight)
      continue;

    Cluster *predC = secToCluster[c.bestPred.from];
    if (predC == &c)
      continue;

    if (c.size + predC->size > MAX_CLUSTER_SIZE)
      continue;

    if (isNewDensityBad(*predC, c))
      continue;

    // NOTE: Consider using a disjoint-set to track section -> cluster mapping
    // if this is ever slow.
    for (int si : c.sections)
      secToCluster[si] = predC;

    mergeClusters(*predC, c);
  }

  // Remove empty or dead nodes. Invalidates all cluster indices.
  llvm::erase_if(clusters, [](const Cluster &c) {
    return c.size == 0 || c.sections.empty();
  });

  // Sort by density.
  llvm::stable_sort(clusters, [](const Cluster &a, const Cluster &b) {
    return a.getDensity() > b.getDensity();
  });
}

DenseMap<const InputSectionBase *, int> CallGraphSort::run() {
  groupClusters();

  // Generate order.
  DenseMap<const InputSectionBase *, int> orderMap;
  ssize_t curOrder = 1;

  for (const Cluster &c : clusters)
    for (int secIndex : c.sections)
      orderMap[sections[secIndex]] = curOrder++;

  if (!config->printSymbolOrder.empty()) {
    std::error_code ec;
    raw_fd_ostream os(config->printSymbolOrder, ec, sys::fs::F_None);
    if (ec) {
      error("cannot open " + config->printSymbolOrder + ": " + ec.message());
      return orderMap;
    }

    // Print the symbols ordered by C3, in the order of increasing curOrder
    // Instead of sorting all the orderMap, just repeat the loops above.
    for (const Cluster &c : clusters)
      for (int secIndex : c.sections)
        // Search all the symbols in the file of the section
        // and find out a Defined symbol with name that is within the section.
        for (Symbol *sym: sections[secIndex]->file->getSymbols())
          if (!sym->isSection()) // Filter out section-type symbols here.
            if (auto *d = dyn_cast<Defined>(sym))
              if (sections[secIndex] == d->section)
                os << sym->getName() << "\n";
  }

  return orderMap;
}

// Sort sections by the profile data provided by -callgraph-profile-file
//
// This first builds a call graph based on the profile data then merges sections
// according to the C³ huristic. All clusters are then sorted by a density
// metric to further improve locality.
DenseMap<const InputSectionBase *, int> elf::computeCallGraphProfileOrder() {
  return CallGraphSort().run();
}
