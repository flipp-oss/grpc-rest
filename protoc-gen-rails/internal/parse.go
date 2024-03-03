package internal

import (
	"encoding/json"
	"fmt"
  options "google.golang.org/genproto/googleapis/api/annotations"
  "google.golang.org/protobuf/proto"
  "google.golang.org/protobuf/types/descriptorpb"
	"regexp"
	"strings"
)

func MethodAndPath(pattern any) (string, string, error) {

	switch typedPattern := pattern.(type) {
	case *options.HttpRule_Get:
		return "GET", typedPattern.Get, nil
	case *options.HttpRule_Post:
		return "POST", typedPattern.Post, nil
	case *options.HttpRule_Put:
		return "PUT", typedPattern.Put, nil
	case *options.HttpRule_Delete:
		return "DELETE", typedPattern.Delete, nil
	case *options.HttpRule_Patch:
		return "PATCH", typedPattern.Patch, nil
	case *options.HttpRule_Custom:
		return typedPattern.Custom.Kind, typedPattern.Custom.Path, nil
	default:
		return "", "", fmt.Errorf("unknown pattern type %T", pattern)
	}
}

type PathInfo struct {
	Name string
	ValPattern string
	SplitName string
	HasValPattern bool
}

func ParsedPath(path string) ([]PathInfo, error) {
	var infos []PathInfo
	re := regexp.MustCompile("\\{(.*?)}")
	matches := re.FindAllString(path, -1)
	for _, match := range matches {
		name := match[1:len(match)-1]
		val := ""
		equal := strings.Index(match, "=")
		if equal != -1 {
			val = name[equal:]
			name = name[0:equal-1]
		}
		splitName := strings.Split(name, ".")
		jsonSplit, err := json.Marshal(splitName)
		if err != nil {
			return nil, fmt.Errorf("error marshalling splitName: %w", err)
		}
		infos = append(infos, PathInfo{
			Name: name,
			ValPattern: val,
			SplitName: string(jsonSplit),
			HasValPattern: val != "",
		})
	}
	return infos, nil
}

func ExtractAPIOptions(meth *descriptorpb.MethodDescriptorProto) (*options.HttpRule, error) {
	if meth.Options == nil {
		return nil, nil
	}
	if !proto.HasExtension(meth.Options, options.E_Http) {
		return nil, nil
	}
	ext := proto.GetExtension(meth.Options, options.E_Http)
	opts, ok := ext.(*options.HttpRule)
	if !ok {
		return nil, fmt.Errorf("extension is %T; want an HttpRule", ext)
	}
	return opts, nil
}


