package main

import (
	"fmt"
	"github.com/flipp-oss/protoc-gen-rails/internal"
	"google.golang.org/protobuf/proto"
	"google.golang.org/protobuf/types/descriptorpb"
	"google.golang.org/protobuf/types/pluginpb"
	"io"
	"log"
	"os"
	"slices"
)

var routes = []internal.Route{}

func processService(service *descriptorpb.ServiceDescriptorProto, pkg string) (internal.FileResult, error) {
	result, serviceRoutes, err := internal.ProcessService(service, pkg)
	if err != nil {
		return internal.FileResult{}, err
	}
	routes = slices.Concat(routes, serviceRoutes)
	return result, nil
}

func routeFile() (internal.FileResult, error) {
	content, err := internal.OutputRoutes(routes)
	if err != nil {
		return internal.FileResult{}, err
	}
	return internal.FileResult{
		Name:    "config/routes/grpc.rb",
		Content: content,
	}, nil
}

func main() {
	req, err := ReadRequest()
	if err != nil {
		log.Fatalf("%s", fmt.Errorf("error reading request: %w", err))
	}
	files := []internal.FileResult{}
	for _, file := range req.GetProtoFile() {
		for _, service := range file.GetService() {
			fileResult, err := processService(service, file.GetPackage())
			if err != nil {
				log.Fatalf("%s", fmt.Errorf("error processing service %v: %w", service.GetName(), err))
			}
			files = append(files, fileResult)
		}
	}
	if len(files) > 0 {
		routeOutput, err := routeFile()
		if err != nil {
			log.Fatalf("%s", fmt.Errorf("error processing routes: %w", err))
		}
		files = append(files, routeOutput)
	}

	// process registry
	writeResponse(files)
}

func ReadRequest() (*pluginpb.CodeGeneratorRequest, error) {
	in, err := io.ReadAll(os.Stdin)
	if err != nil {
		return nil, err
	}
	req := &pluginpb.CodeGeneratorRequest{}
	err = proto.Unmarshal(in, req)
	if err != nil {
		return nil, err
	}
	return req, nil
}

func generateResponse(files []internal.FileResult) *pluginpb.CodeGeneratorResponse {
	feature := uint64(pluginpb.CodeGeneratorResponse_FEATURE_PROTO3_OPTIONAL)
	respFiles := make([]*pluginpb.CodeGeneratorResponse_File, len(files))
	for i, file := range files {
		respFiles[i] = &pluginpb.CodeGeneratorResponse_File{
			Name:    &file.Name,
			Content: &file.Content,
		}

	}
	return &pluginpb.CodeGeneratorResponse{
		SupportedFeatures: &feature,
		File: respFiles,
	}
}

func writeResponse(files []internal.FileResult) {
	response := generateResponse(files)
	out, err := proto.Marshal(response)
	if err != nil {
		log.Fatalf("%s", fmt.Errorf("error marshalling response: %w", err))
	}
	_, err = os.Stdout.Write(out)
	if err != nil {
		log.Fatalf("%s", fmt.Errorf("error writing response: %w", err))
	}
}

