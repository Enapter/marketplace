package main

import (
	"errors"
	"flag"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"strings"

	"gopkg.in/yaml.v3"
)

const (
	devicesFile = ".marketplace/devices/devices.yml"
	vendorsFile = ".marketplace/vendors/vendors.yml"
)

var errLinterFailed = errors.New("linter failed")

type VerificationLevel = string

const (
	VerificationLevelReadyForTesting VerificationLevel = "ready_for_testing"
	VerificationLevelCommunityTested VerificationLevel = "community_tested"
	VerificationLevelVerified        VerificationLevel = "verified"
)

type vendorID = string

type Vendor struct {
	ID string `yaml:"id"`
}

type Device struct {
	ID               yaml.Node `yaml:"id"`
	DisplayName      yaml.Node `yaml:"display_name"`
	Description      yaml.Node `yaml:"description"`
	IconID           yaml.Node `yaml:"icon"`
	VendorID         yaml.Node `yaml:"vendor,omitempty"`
	CategoryID       yaml.Node `yaml:"category"`
	BlueprintOptions yaml.Node `yaml:"blueprint_options"`
}

type BlueprintOption struct {
	Blueprint         yaml.Node `yaml:"blueprint"`
	DisplayName       yaml.Node `yaml:"display_name"`
	Description       yaml.Node `yaml:"description"`
	VerificationLevel yaml.Node `yaml:"verification_level"`
}

type Node struct {
	yaml.Node
	Root yaml.Node
}

func main() {
	marketplacePath := flag.String("p", "./", "path to marketplace directory")
	flag.Parse()

	if err := run(*marketplacePath, flag.Args()); err != nil {
		if !errors.Is(err, errLinterFailed) {
			fmt.Fprintf(os.Stdout, "::error:: failed run marketplace devcies validation %s\n", err)
		}
		os.Exit(1)
	}
}

func run(marketplacePath string, changedFilesPaths []string) error {
	if !devicesFileChanged(changedFilesPaths) {
		return nil
	}

	vendorIDs, err := parseVendorIDs(filepath.Join(marketplacePath, vendorsFile))
	if err != nil {
		return fmt.Errorf("parse vendors: %w", err)
	}

	devices, err := parseDevices(filepath.Join(marketplacePath, devicesFile))
	if err != nil {
		return fmt.Errorf("parse devices: %w", err)
	}

	err = validateDevices(devices, vendorIDs)
	if err != nil {
		return fmt.Errorf("validate devices: %w", err)
	}

	return nil
}

func devicesFileChanged(changedFiles []string) bool {
	for _, file := range changedFiles {
		if file == devicesFile {
			return true
		}
	}
	return false
}

func parseVendorIDs(filePath string) (map[vendorID]struct{}, error) {
	f, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("open file: %w", err)
	}
	defer f.Close()

	var vendors []Vendor
	err = yaml.NewDecoder(f).Decode(&vendors)
	if err != nil {
		return nil, fmt.Errorf("parse yaml: %w", err)
	}

	vendorsMap := make(map[vendorID]struct{}, len(vendors))

	for _, v := range vendors {
		vendorsMap[v.ID] = struct{}{}
	}

	return vendorsMap, nil
}

func parseDevices(filePath string) ([]Device, error) {
	f, err := os.Open(filePath)
	if err != nil {
		return nil, fmt.Errorf("open file: %w", err)
	}
	defer f.Close()

	var devices []Device
	err = yaml.NewDecoder(f).Decode(&devices)
	if err != nil {
		return nil, fmt.Errorf("parse yaml: %w", err)
	}

	return devices, nil
}

func validateDevices(devices []Device, vendorIDs map[vendorID]struct{}) error {
	resOk := true
	devicesIDs := make(map[string]struct{}, len(devices))

	for _, d := range devices {
		if _, found := devicesIDs[d.ID.Value]; found {
			logDeviceWarning(d.ID.Line, d.ID.Column, "not unique device id")
			resOk = false
			continue
		}

		devicesIDs[d.ID.Value] = struct{}{}

		if !checkRequiredAndNotEmpty("display_name", newNode(d.DisplayName, d.ID)) {
			resOk = false
		}

		if !checkRequiredAndNotEmpty("description", newNode(d.Description, d.ID)) {
			resOk = false
		}

		ok, err := validateDeviceIcon("icon", newNode(d.IconID, d.ID))
		if err != nil {
			return fmt.Errorf("validate device icon: %w", err)
		}

		if !ok {
			resOk = false
		}

		ok, err = validateCategory("category", newNode(d.CategoryID, d.ID))
		if err != nil {
			return fmt.Errorf("validate device category: %w", err)
		}

		if !ok {
			resOk = false
		}

		if !validateVendor(newNode(d.VendorID, d.ID), vendorIDs) {
			resOk = false
		}

		ok, err = validateBlueprintOptions("blueprint_options", newNode(d.BlueprintOptions, d.ID))
		if err != nil {
			return fmt.Errorf("validate device blueprint options: %w", err)
		}

		if !ok {
			resOk = false
		}
	}

	if !resOk {
		return errLinterFailed
	}

	return nil
}

func validateDeviceIcon(name string, node Node) (bool, error) {
	if !checkRequiredAndNotEmpty(name, node) {
		return false, nil
	}

	iconURL := fmt.Sprintf("https://static.enapter.com/material-community/%s.svg", node.Value)

	if strings.HasPrefix(node.Value, "enapter") {
		iconURL = fmt.Sprintf("https://static.enapter.com/enapter-icons/%s.svg", node.Value)
	}

	ok, err := checkResourceExistsAtURL(iconURL)
	if err != nil {
		return false, fmt.Errorf("check blueprint icon: %w", err)
	}

	if !ok {
		logDeviceWarning(
			node.Line, node.Column,
			"icon should be sourced from Enapter Energy Icon "+
				"(https://handbook.enapter.com/icons.html) or "+
				"Material Community "+
				"(https://static.enapter.com/rn/icons/material-community.html) assets only",
		)
		return false, nil
	}

	return true, nil
}

func validateVendor(node Node, ids map[vendorID]struct{}) bool {
	if node.Value == "" {
		return true
	}

	if _, ok := ids[node.Value]; !ok {
		logDeviceWarning(
			node.Line, node.Column,
			fmt.Sprintf("vendor id %q not found at the %s", node.Value, vendorsFile),
		)
		return false
	}

	return true
}

func validateCategory(name string, node Node) (bool, error) {
	if !checkRequiredAndNotEmpty(name, node) {
		return false, nil
	}

	_, err := os.ReadDir(node.Value)
	if err != nil {
		if os.IsNotExist(err) {
			logDeviceWarning(node.Line, node.Column, fmt.Sprintf("%s category is not exist", node.Value))
			return false, nil
		}
		return false, err
	}

	return true, nil
}

func validateBlueprintOptions(name string, node Node) (bool, error) {
	if !checkRequiredValue(name, node) {
		return false, nil
	}

	var opts []BlueprintOption
	err := node.Decode(&opts)
	if err != nil {
		return false, fmt.Errorf("decode: %w", err)
	}

	if len(opts) == 0 {
		logDeviceWarning(node.Line, node.Column, "blueprint_options is required")
		return false, nil
	}

	for _, opt := range opts {
		if !checkRequiredAndNotEmpty("blueprint", newNode(opt.Blueprint, node.Node)) {
			return false, nil
		}

		_, err := os.Open(filepath.Join(opt.Blueprint.Value, "manifest.yml"))
		if err != nil {
			if os.IsNotExist(err) {
				logDeviceWarning(
					opt.Blueprint.Line, opt.Blueprint.Column,
					fmt.Sprintf("%s probably is not a blueprint", opt.Blueprint.Value),
				)
				return false, nil
			}
			return false, err
		}

		if !checkRequiredAndNotEmpty("verification_level", newNode(opt.VerificationLevel, opt.Blueprint)) {
			return false, nil
		}

		switch opt.VerificationLevel.Value {
		case VerificationLevelVerified,
			VerificationLevelReadyForTesting,
			VerificationLevelCommunityTested:
		default:
			logDeviceWarning(
				opt.VerificationLevel.Line,
				opt.VerificationLevel.Column,
				"verification level should be "+
					"'verified', 'community_tested' or 'ready_for_testing' only",
			)
			return false, nil
		}

		if len(opts) > 1 {
			if !checkRequiredAndNotEmpty("display_name", newNode(opt.DisplayName, opt.Blueprint)) {
				return false, nil
			}

			if !checkRequiredAndNotEmpty("description", newNode(opt.Description, opt.Blueprint)) {
				return false, nil
			}
		}
	}

	return true, nil
}

func checkRequiredAndNotEmpty(name string, node Node) bool {
	if !checkRequiredValue(name, node) {
		return false
	}

	if node.Value == "" {
		logDeviceWarning(node.Line, node.Column, fmt.Sprintf("%s should not be empty", name))
		return false
	}

	return true
}

func checkRequiredValue(name string, node Node) bool {
	if node.IsZero() {
		logDeviceWarning(node.Root.Line, node.Root.Column, fmt.Sprintf("%s is required", name))
		return false
	}
	return true
}

func checkResourceExistsAtURL(url string) (bool, error) {
	r, err := http.Get(url)
	if err != nil {
		return false, fmt.Errorf("check url: %w", err)
	}
	defer r.Body.Close()

	return r.StatusCode == http.StatusOK, nil
}

func newNode(node yaml.Node, root yaml.Node) Node {
	return Node{Node: node, Root: root}
}

func logDeviceWarning(line, column int, msg string) {
	var builder strings.Builder

	builder.WriteString(devicesFile)
	if line != 0 {
		builder.WriteString(fmt.Sprintf(":%d", line))
	}
	builder.WriteString(": " + msg)

	fmt.Fprintf(os.Stdout, "::warning file=%s,line=%d,col=%d::%s\n", devicesFile, line, column, builder.String())
}
