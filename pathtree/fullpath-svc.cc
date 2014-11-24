// fullpath-svc.cc: serve fullpath queries on TCP socket
// compile: g++ --std=c++0x -o fullpath-svc fullpath-svc.cc -lboost_system -lpthread
// run: ./fullpath-svc < x.fullpath
// input on fullpath-svc.sock: fh (one per line)
// output on fullpath-svc.sock: fullpath record (CSV)

#include <cassert>
#include <tuple>
#include <string>
#include <unordered_map>
#include <iostream>
#include <fstream>

#include <boost/asio.hpp>

typedef std::unordered_map<std::string, std::string> Table; // fh=>line

Table
parseInput(std::istream& input)
{
  Table table;
  int i = 0;
  std::string line;
  while (input >> line) {
    if (++i % 100000 == 0) {
      std::cerr << "load " << i << std::endl;
    }
    size_t pos = line.find(',');
    assert(pos != std::string::npos);
    std::string fh = line.substr(0, pos);
    table[fh] = line;
  }
  std::cerr << "OK" << std::endl;
  return table;
}

typedef boost::asio::local::stream_protocol Protocol;

void
serveSocket(const Table& table, Protocol::iostream& stream)
{
  std::string fh;
  while (std::getline(stream, fh)) {
    auto it = table.find(fh);
    if (it == table.end()) {
      stream << fh << std::endl;
    }
    else {
      stream << it->second << std::endl;
    }
  }
}

void
serveForever(std::function<void(Protocol::iostream& stream)> f)
{
  boost::asio::io_service io;
  boost::system::error_code ec;

  Protocol::acceptor acceptor(io, Protocol::endpoint("fullpath-svc.sock"));
  while (true) {
    Protocol::iostream stream;
    acceptor.accept(*stream.rdbuf(), ec);
    if (!ec) {
      f(stream);
    }
  }
}

int
main()
{
  Table table = parseInput(std::cin);
  serveForever(std::bind(&serveSocket, std::cref(table), std::placeholders::_1));
  return 0;
}
