/*****************************************************************************

                                dbg(...) macro

License (MIT):

  Copyright (c) 2019 David Peter <mail@david-peter.de>

  Permission is hereby granted, free of charge, to any person obtaining a copy
  of this software and associated documentation files (the "Software"), to
  deal in the Software without restriction, including without limitation the
  rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
  sell copies of the Software, and to permit persons to whom the Software is
  furnished to do so, subject to the following conditions:

  The above copyright notice and this permission notice shall be included in
  all copies or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
  SOFTWARE.

*****************************************************************************/

#ifndef DBG_MACRO_DBG_H
#define DBG_MACRO_DBG_H

#if defined(__unix__) || (defined(__APPLE__) && defined(__MACH__))
#define DBG_MACRO_UNIX
#elif defined(_MSC_VER)
#define DBG_MACRO_WINDOWS
#endif

#ifndef DBG_MACRO_NO_WARNING
#pragma message("WARNING: the 'dbg.h' header is included in your code base")
#endif  // DBG_MACRO_NO_WARNING

#include <algorithm>
#include <chrono>
#include <ctime>
#include <iomanip>
#include <ios>
#include <iostream>
#include <memory>
#include <sstream>
#include <string>
#include <tuple>
#include <type_traits>
#include <vector>

#ifdef DBG_MACRO_UNIX
#include <unistd.h>
#endif

#if __cplusplus >= 201703L || defined(_MSC_VER)
#define DBG_MACRO_CXX_STANDARD 17
#elif __cplusplus >= 201402L
#define DBG_MACRO_CXX_STANDARD 14
#else
#define DBG_MACRO_CXX_STANDARD 11
#endif

#if DBG_MACRO_CXX_STANDARD >= 17
#include <optional>
#include <variant>
#endif

namespace dbg {

#ifdef DBG_MACRO_UNIX
inline bool isColorizedOutputEnabled() {
  return isatty(fileno(stderr));
}
#else
inline bool isColorizedOutputEnabled() {
  return true;
}
#endif

struct time {};

namespace pretty_function {

// Compiler-agnostic version of __PRETTY_FUNCTION__ and constants to
// extract the template argument in `type_name_impl`

#if defined(__clang__)
#define DBG_MACRO_PRETTY_FUNCTION __PRETTY_FUNCTION__
static constexpr size_t PREFIX_LENGTH =
    sizeof("const char *dbg::type_name_impl() [T = ") - 1;
static constexpr size_t SUFFIX_LENGTH = sizeof("]") - 1;
#elif defined(__GNUC__) && !defined(__clang__)
#define DBG_MACRO_PRETTY_FUNCTION __PRETTY_FUNCTION__
static constexpr size_t PREFIX_LENGTH =
    sizeof("const char* dbg::type_name_impl() [with T = ") - 1;
static constexpr size_t SUFFIX_LENGTH = sizeof("]") - 1;
#elif defined(_MSC_VER)
#define DBG_MACRO_PRETTY_FUNCTION __FUNCSIG__
static constexpr size_t PREFIX_LENGTH =
    sizeof("const char *__cdecl dbg::type_name_impl<") - 1;
static constexpr size_t SUFFIX_LENGTH = sizeof(">(void)") - 1;
#else
#error "This compiler is currently not supported by dbg_macro."
#endif

}  // namespace pretty_function

// Formatting helpers

template <typename T>
struct print_formatted {
  static_assert(std::is_integral<T>::value,
                "Only integral types are supported.");

  print_formatted(T value, int numeric_base)
      : inner(value), base(numeric_base) {}

  operator T() const { return inner; }

  const char* prefix() const {
    switch (base) {
      case 8:
        return "0o";
      case 16:
        return "0x";
      case 2:
        return "0b";
      default:
        return "";
    }
  }

  T inner;
  int base;
};

template <typename T>
print_formatted<T> hex(T value) {
  return print_formatted<T>{value, 16};
}

template <typename T>
print_formatted<T> oct(T value) {
  return print_formatted<T>{value, 8};
}

template <typename T>
print_formatted<T> bin(T value) {
  return print_formatted<T>{value, 2};
}

// Implementation of 'type_name<T>()'

template <typename T>
const char* type_name_impl() {
  return DBG_MACRO_PRETTY_FUNCTION;
}

template <typename T>
struct type_tag {};

template <int&... ExplicitArgumentBarrier, typename T>
std::string get_type_name(type_tag<T>) {
  namespace pf = pretty_function;

  std::string type = type_name_impl<T>();
  return type.substr(pf::PREFIX_LENGTH,
                     type.size() - pf::PREFIX_LENGTH - pf::SUFFIX_LENGTH);
}

template <typename T>
std::string type_name() {
  if (std::is_volatile<T>::value) {
    if (std::is_pointer<T>::value) {
      return type_name<typename std::remove_volatile<T>::type>() + " volatile";
    } else {
      return "volatile " + type_name<typename std::remove_volatile<T>::type>();
    }
  }
  if (std::is_const<T>::value) {
    if (std::is_pointer<T>::value) {
      return type_name<typename std::remove_const<T>::type>() + " const";
    } else {
      return "const " + type_name<typename std::remove_const<T>::type>();
    }
  }
  if (std::is_pointer<T>::value) {
    return type_name<typename std::remove_pointer<T>::type>() + "*";
  }
  if (std::is_lvalue_reference<T>::value) {
    return type_name<typename std::remove_reference<T>::type>() + "&";
  }
  if (std::is_rvalue_reference<T>::value) {
    return type_name<typename std::remove_reference<T>::type>() + "&&";
  }
  return get_type_name(type_tag<T>{});
}

inline std::string get_type_name(type_tag<short>) {
  return "short";
}

inline std::string get_type_name(type_tag<unsigned short>) {
  return "unsigned short";
}

inline std::string get_type_name(type_tag<long>) {
  return "long";
}

inline std::string get_type_name(type_tag<unsigned long>) {
  return "unsigned long";
}

inline std::string get_type_name(type_tag<std::string>) {
  return "std::string";
}

template <typename T>
std::string get_type_name(type_tag<std::vector<T, std::allocator<T>>>) {
  return "std::vector<" + type_name<T>() + ">";
}

template <typename T1, typename T2>
std::string get_type_name(type_tag<std::pair<T1, T2>>) {
  return "std::pair<" + type_name<T1>() + ", " + type_name<T2>() + ">";
}

template <typename... T>
std::string type_list_to_string() {
  std::string result;
  auto unused = {(result += type_name<T>() + ", ", 0)..., 0};
  static_cast<void>(unused);

  if (sizeof...(T) > 0) {
    result.pop_back();
    result.pop_back();
  }
  return result;
}

template <typename... T>
std::string get_type_name(type_tag<std::tuple<T...>>) {
  return "std::tuple<" + type_list_to_string<T...>() + ">";
}

template <typename T>
inline std::string get_type_name(type_tag<print_formatted<T>>) {
  return type_name<T>();
}

// Implementation of 'is_detected' to specialize for container-like types

namespace detail_detector {

struct nonesuch {
  nonesuch() = delete;
  ~nonesuch() = delete;
  nonesuch(nonesuch const&) = delete;
  void operator=(nonesuch const&) = delete;
};

template <typename...>
using void_t = void;

template <class Default,
          class AlwaysVoid,
          template <class...>
          class Op,
          class... Args>
struct detector {
  using value_t = std::false_type;
  using type = Default;
};

template <class Default, template <class...> class Op, class... Args>
struct detector<Default, void_t<Op<Args...>>, Op, Args...> {
  using value_t = std::true_type;
  using type = Op<Args...>;
};

}  // namespace detail_detector

template <template <class...> class Op, class... Args>
using is_detected = typename detail_detector::
    detector<detail_detector::nonesuch, void, Op, Args...>::value_t;

namespace detail {

namespace {
using std::begin;
using std::end;
#if DBG_MACRO_CXX_STANDARD < 17
template <typename T>
constexpr auto size(const T& c) -> decltype(c.size()) {
  return c.size();
}
template <typename T, std::size_t N>
constexpr std::size_t size(const T (&)[N]) {
  return N;
}
#else
using std::size;
#endif
}  // namespace

template <typename T>
using detect_begin_t = decltype(detail::begin(std::declval<T>()));

template <typename T>
using detect_end_t = decltype(detail::end(std::declval<T>()));

template <typename T>
using detect_size_t = decltype(detail::size(std::declval<T>()));

template <typename T>
struct is_container {
  static constexpr bool value =
      is_detected<detect_begin_t, T>::value &&
      is_detected<detect_end_t, T>::value &&
      is_detected<detect_size_t, T>::value &&
      !std::is_same<std::string,
                    typename std::remove_cv<
                        typename std::remove_reference<T>::type>::type>::value;
};

template <typename T>
using ostream_operator_t =
    decltype(std::declval<std::ostream&>() << std::declval<T>());

template <typename T>
struct has_ostream_operator : is_detected<ostream_operator_t, T> {};

}  // namespace detail

// Helper to dbg(…)-print types
template <typename T>
struct print_type {};

template <typename T>
print_type<T> type() {
  return print_type<T>{};
}

// Specializations of "pretty_print"

template <typename T>
inline void pretty_print(std::ostream& stream, const T& value, std::true_type) {
  stream << value;
}

template <typename T>
inline void pretty_print(std::ostream&, const T&, std::false_type) {
  static_assert(detail::has_ostream_operator<const T&>::value,
                "Type does not support the << ostream operator");
}

template <typename T>
inline typename std::enable_if<!detail::is_container<const T&>::value &&
                                   !std::is_enum<T>::value,
                               bool>::type
pretty_print(std::ostream& stream, const T& value) {
  pretty_print(stream, value,
               typename detail::has_ostream_operator<const T&>::type{});
  return true;
}

inline bool pretty_print(std::ostream& stream, const bool& value) {
  stream << std::boolalpha << value;
  return true;
}

inline bool pretty_print(std::ostream& stream, const char& value) {
  const bool printable = value >= 0x20 && value <= 0x7E;

  if (printable) {
    stream << "'" << value << "'";
  } else {
    stream << "'\\x" << std::setw(2) << std::setfill('0') << std::hex
           << std::uppercase << (0xFF & value) << "'";
  }
  return true;
}

template <typename P>
inline bool pretty_print(std::ostream& stream, P* const& value) {
  if (value == nullptr) {
    stream << "nullptr";
  } else {
    stream << value;
  }
  return true;
}

template <typename T, typename Deleter>
inline bool pretty_print(std::ostream& stream,
                         std::unique_ptr<T, Deleter>& value) {
  pretty_print(stream, value.get());
  return true;
}

template <typename T>
inline bool pretty_print(std::ostream& stream, std::shared_ptr<T>& value) {
  pretty_print(stream, value.get());
  stream << " (use_count = " << value.use_count() << ")";

  return true;
}

template <size_t N>
inline bool pretty_print(std::ostream& stream, const char (&value)[N]) {
  stream << value;
  return false;
}

template <>
inline bool pretty_print(std::ostream& stream, const char* const& value) {
  stream << '"' << value << '"';
  return true;
}

template <size_t Idx>
struct pretty_print_tuple {
  template <typename... Ts>
  static void print(std::ostream& stream, const std::tuple<Ts...>& tuple) {
    pretty_print_tuple<Idx - 1>::print(stream, tuple);
    stream << ", ";
    pretty_print(stream, std::get<Idx>(tuple));
  }
};

template <>
struct pretty_print_tuple<0> {
  template <typename... Ts>
  static void print(std::ostream& stream, const std::tuple<Ts...>& tuple) {
    pretty_print(stream, std::get<0>(tuple));
  }
};

template <typename... Ts>
inline bool pretty_print(std::ostream& stream, const std::tuple<Ts...>& value) {
  stream << "{";
  pretty_print_tuple<sizeof...(Ts) - 1>::print(stream, value);
  stream << "}";

  return true;
}

template <>
inline bool pretty_print(std::ostream& stream, const std::tuple<>&) {
  stream << "{}";

  return true;
}

template <>
inline bool pretty_print(std::ostream& stream, const time&) {
  using namespace std::chrono;

  const auto now = system_clock::now();
  const auto us =
      duration_cast<microseconds>(now.time_since_epoch()).count() % 1000000;
  const auto hms = system_clock::to_time_t(now);
  const std::tm* tm = std::localtime(&hms);
  stream << "current time = " << std::put_time(tm, "%H:%M:%S") << '.'
         << std::setw(6) << std::setfill('0') << us;

  return false;
}

// Converts decimal integer to binary string
template <typename T>
std::string decimalToBinary(T n) {
  const size_t length = 8 * sizeof(T);
  std::string toRet;
  toRet.resize(length);

  for (size_t i = 0; i < length; ++i) {
    const auto bit_at_index_i = (n >> i) & 1;
    toRet[length - 1 - i] = bit_at_index_i + '0';
  }

  return toRet;
}

template <typename T>
inline bool pretty_print(std::ostream& stream,
                         const print_formatted<T>& value) {
  if (value.inner < 0) {
    stream << "-";
  }
  stream << value.prefix();

  // Print using setbase
  if (value.base != 2) {
    stream << std::setw(sizeof(T)) << std::setfill('0')
           << std::setbase(value.base) << std::uppercase;

    if (value.inner >= 0) {
      // The '+' sign makes sure that a uint_8 is printed as a number
      stream << +value.inner;
    } else {
      using unsigned_type = typename std::make_unsigned<T>::type;
      stream << +(static_cast<unsigned_type>(-(value.inner + 1)) + 1);
    }
  } else {
    // Print for binary
    if (value.inner >= 0) {
      stream << decimalToBinary(value.inner);
    } else {
      using unsigned_type = typename std::make_unsigned<T>::type;
      stream << decimalToBinary<unsigned_type>(
          static_cast<unsigned_type>(-(value.inner + 1)) + 1);
    }
  }

  return true;
}

template <typename T>
inline bool pretty_print(std::ostream& stream, const print_type<T>&) {
  stream << type_name<T>();

  stream << " [sizeof: " << sizeof(T) << " byte, ";

  stream << "trivial: ";
  if (std::is_trivial<T>::value) {
    stream << "yes";
  } else {
    stream << "no";
  }

  stream << ", standard layout: ";
  if (std::is_standard_layout<T>::value) {
    stream << "yes";
  } else {
    stream << "no";
  }
  stream << "]";

  return false;
}

template <typename Container>
inline typename std::enable_if<detail::is_container<const Container&>::value,
                               bool>::type
pretty_print(std::ostream& stream, const Container& value) {
  stream << "{";
  const size_t size = detail::size(value);
  const size_t n = std::min(size_t{10}, size);
  size_t i = 0;
  using std::begin;
  using std::end;
  for (auto it = begin(value); it != end(value) && i < n; ++it, ++i) {
    pretty_print(stream, *it);
    if (i != n - 1) {
      stream << ", ";
    }
  }

  if (size > n) {
    stream << ", ...";
    stream << " size:" << size;
  }

  stream << "}";
  return true;
}

template <typename Enum>
inline typename std::enable_if<std::is_enum<Enum>::value, bool>::type
pretty_print(std::ostream& stream, Enum const& value) {
  using UnderlyingType = typename std::underlying_type<Enum>::type;
  stream << static_cast<UnderlyingType>(value);

  return true;
}

inline bool pretty_print(std::ostream& stream, const std::string& value) {
  stream << '"' << value << '"';
  return true;
}

template <typename T1, typename T2>
inline bool pretty_print(std::ostream& stream, const std::pair<T1, T2>& value) {
  stream << "{";
  pretty_print(stream, value.first);
  stream << ", ";
  pretty_print(stream, value.second);
  stream << "}";
  return true;
}

#if DBG_MACRO_CXX_STANDARD >= 17

template <typename T>
inline bool pretty_print(std::ostream& stream, const std::optional<T>& value) {
  if (value) {
    stream << '{';
    pretty_print(stream, *value);
    stream << '}';
  } else {
    stream << "nullopt";
  }

  return true;
}

template <typename... Ts>
inline bool pretty_print(std::ostream& stream,
                         const std::variant<Ts...>& value) {
  stream << "{";
  std::visit([&stream](auto&& arg) { pretty_print(stream, arg); }, value);
  stream << "}";

  return true;
}

#endif

class DebugOutput {
 public:
  DebugOutput(const char* filepath,
              int line,
              const char* function_name,
              const char* expression)
      : m_use_colorized_output(isColorizedOutputEnabled()),
        m_filepath(filepath),
        m_line(line),
        m_function_name(function_name),
        m_expression(expression) {
    const std::size_t path_length = m_filepath.length();
    if (path_length > MAX_PATH_LENGTH) {
      m_filepath = ".." + m_filepath.substr(path_length - MAX_PATH_LENGTH,
                                            MAX_PATH_LENGTH);
    }
  }

  template <typename T>
  T&& print(const std::string& type, T&& value) const {
    const T& ref = value;
    std::stringstream stream_value;
    const bool print_expr_and_type = pretty_print(stream_value, ref);

    std::stringstream output;
    output << ansi(ANSI_DEBUG) << "[" << m_filepath << ":" << m_line << " ("
           << m_function_name << ")] " << ansi(ANSI_RESET);
    if (print_expr_and_type) {
      output << ansi(ANSI_EXPRESSION) << m_expression << ansi(ANSI_RESET)
             << " = ";
    }
    output << ansi(ANSI_VALUE) << stream_value.str() << ansi(ANSI_RESET);
    if (print_expr_and_type) {
      output << " (" << ansi(ANSI_TYPE) << type << ansi(ANSI_RESET) << ")";
    }
    output << std::endl;
    std::cerr << output.str();

    return std::forward<T>(value);
  }

 private:
  const char* ansi(const char* code) const {
    if (m_use_colorized_output) {
      return code;
    } else {
      return ANSI_EMPTY;
    }
  }

  const bool m_use_colorized_output;

  std::string m_filepath;
  const int m_line;
  const std::string m_function_name;
  const std::string m_expression;

  static constexpr std::size_t MAX_PATH_LENGTH = 20;

  static constexpr const char* const ANSI_EMPTY = "";
  static constexpr const char* const ANSI_DEBUG = "\x1b[02m";
  static constexpr const char* const ANSI_EXPRESSION = "\x1b[36m";
  static constexpr const char* const ANSI_VALUE = "\x1b[01m";
  static constexpr const char* const ANSI_TYPE = "\x1b[32m";
  static constexpr const char* const ANSI_RESET = "\x1b[0m";
};

// Identity function to suppress "-Wunused-value" warnings in DBG_MACRO_DISABLE
// mode
template <typename T>
T&& identity(T&& t) {
  return std::forward<T>(t);
}

}  // namespace dbg

#ifndef DBG_MACRO_DISABLE
// We use a variadic macro to support commas inside expressions (e.g.
// initializer lists):
#define dbg(...)                                               \
  dbg::DebugOutput(__FILE__, __LINE__, __func__, #__VA_ARGS__) \
      .print(dbg::type_name<decltype(__VA_ARGS__)>(), (__VA_ARGS__))
#else
#define dbg(...) dbg::identity(__VA_ARGS__)
#endif  // DBG_MACRO_DISABLE

#endif  // DBG_MACRO_DBG_H
