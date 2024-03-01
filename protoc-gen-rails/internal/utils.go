package internal

import (
  "fmt"
  "github.com/iancoleman/strcase"
  "os"
  "regexp"
  "strings"
)

func LogMsg(msg string, args ...any) {
	fmt.Fprintf(os.Stderr, fmt.Sprintf(msg, args...))
	fmt.Fprintln(os.Stderr)
}

func FilePathify(s string) string {
	var result []string
	s = strings.Trim(s, ".")
	tokens := strings.Split(s, ".")
	for _, token := range tokens {
		result = append(result, strcase.ToSnake(token))
	}
	return strings.Join(result, "/")
}

func Classify(s string) string {
	var result []string
	s = strings.Trim(s, ".")
	tokens := strings.Split(s, ".")
	for _, token := range tokens {
		result = append(result, strcase.ToCamel(token))
	}
	return strings.Join(result, "::")
}

func Demodulize(s string) string {
	tokens := strings.Split(s, ".")
	return tokens[len(tokens)-1]
}

func SanitizePath(s string) string {
  re := regexp.MustCompile("\\{(.*?)}")
	matches := re.FindAllStringSubmatch(s, -1)
	for _, match := range matches {
		repl := match[1]
		equal := strings.Index(match[1], "=")
		if equal != -1 {
			repl = repl[0:equal]
		}
		dot := strings.Index(repl, ".")
		if dot != -1 {
			repl = repl[dot+1:]
		}
		s = strings.Replace(s, match[0], ":"+repl, 1)
	}
  return s
}
