// fullpath.cc: reconstruct full path for each filehandle from fhparent mapping
// compile: g++ --std=c++0x -o fullpath fullpath.cc
// run: cat x.fhparent | tr ',' '\t' | ./fullpath > x.fullpath
// stdin: CSV fh,name,parent
// stdout: CSV fh,top-level unresolved fh,path

#include <tuple>
#include <string>
#include <unordered_map>
#include <iostream>
#include <fstream>

const int PROGRESS = 100000; // interval of progress report, 0 to disable
std::string progressHeading = "PROGRESS";
int progressCount = 0;

// http://stackoverflow.com/a/19770392/3729203
void process_mem_usage(double& vm_usage, double& resident_set)
{
    vm_usage     = 0.0;
    resident_set = 0.0;

    // the two fields we want
    unsigned long vsize;
    long rss;
    {
        std::string ignore;
        std::ifstream ifs("/proc/self/stat", std::ios_base::in);
        ifs >> ignore >> ignore >> ignore >> ignore >> ignore >> ignore >> ignore >> ignore >> ignore >> ignore
                >> ignore >> ignore >> ignore >> ignore >> ignore >> ignore >> ignore >> ignore >> ignore >> ignore
                >> ignore >> ignore >> vsize >> rss;
    }

    long page_size_kb = sysconf(_SC_PAGE_SIZE) / 1024; // in case x86-64 is configured to use 2MB pages
    vm_usage = vsize / 1024.0;
    resident_set = rss * page_size_kb;
}

void
incrementProgress()
{
  double vm_usage, resident_set;
  if (PROGRESS > 0 && (++progressCount) % PROGRESS == 0) {
    process_mem_usage(vm_usage, resident_set);
    std::cerr << progressHeading << " " << progressCount << " " << resident_set << std::endl;
  }
}

struct Relation
{
  std::string name;
  std::string parent;
  bool mountpoint;
};
typedef std::unordered_map<std::string, Relation> Relations; // fh=>relation

Relations
parseInput(std::istream& input)
{
  Relations relations;
  progressHeading = "parse";
  progressCount = 0;

  std::string fh, name, parent;
  while (input >> fh >> name >> parent) {
    Relation& relation = relations[fh];
    relation.name = name;
    relation.mountpoint = parent == "MOUNTPOINT";
    if (!relation.mountpoint) {
      relation.parent = parent;
    }
    incrementProgress();
  }
  return relations;
}

std::tuple<std::string, std::string> // top, path
constructPath(const Relations& relations, std::string fh, std::string tail = "")
{
  auto relationIt = relations.find(fh);
  if (relationIt == relations.end()) { // unresolved
    return std::forward_as_tuple(fh, tail);
  }
  const Relation& relation = relationIt->second;

  std::string newTail = relation.name;
  if (!tail.empty()) {
    newTail.push_back('/');
    newTail.append(tail);
  }

  if (relation.mountpoint) {
    return std::forward_as_tuple("", newTail);
  }

  return constructPath(relations, relation.parent, newTail);
}

void
writeResults(const Relations& relations, std::ostream& output)
{
  progressHeading = "output";
  progressCount = 0;

  for (const auto& pair : relations) {
    const std::string& fh = pair.first;
    const Relation& relation = pair.second;
    std::string top, path;
    std::tie(top, path) = constructPath(relations, fh);

    output << fh << ',' << top << ',' << path << '\n';
    incrementProgress();
  }
}

int
main()
{
  Relations relations = parseInput(std::cin);
  writeResults(relations, std::cout);
  return 0;
}
