package main

import (
	"errors"
	"flag"
	"fmt"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strings"

	"gopkg.in/yaml.v3"
)

const (
	vendorsFile   = ".marketplace/vendors/vendors.yml"
	iconURLPrefix = "https://raw.githubusercontent.com/Enapter/marketplace/main/.marketplace/vendors/icons/"
)

var (
	errMissedRequiredParam = errors.New("missed required parameter")
	errLinterFailed        = errors.New("linter failed")
)

type Vendor struct {
	ID          yaml.Node `yaml:"id"`
	DisplayName yaml.Node `yaml:"display_name"`
	IconURL     yaml.Node `yaml:"icon_url"`
	Website     yaml.Node `yaml:"website"`
}

type Node struct {
	yaml.Node
	Root yaml.Node
}

func main() {
	marketplacePath := flag.String("p", "./", "path to marketplace directory")
	repo := flag.String("r", "", "repository")
	branch := flag.String("b", "", "branch")
	flag.Parse()

	if err := run(*repo, *branch, *marketplacePath, flag.Args()); err != nil {
		if !errors.Is(err, errLinterFailed) {
			fmt.Fprintf(os.Stdout, "::error:: failed run marketplace vendors validation %s\n", err)
		}
		os.Exit(1)
	}
}

func run(repo, branch, marketplacePath string, changedFilesPaths []string) error {
	if err := checkParams(repo, branch); err != nil {
		return fmt.Errorf("check incoming params: %w", err)
	}

	if !vendorsFileChanged(changedFilesPaths) {
		return nil
	}

	vendors, err := parseVendors(filepath.Join(marketplacePath, vendorsFile))
	if err != nil {
		return fmt.Errorf("parse vendors: %w", err)
	}

	err = validateVendors(vendors, strings.Join([]string{repo, branch}, "/"))
	if err != nil {
		return fmt.Errorf("validate vendors: %w", err)
	}

	return nil
}

func checkParams(repo, branch string) error {
	if repo == "" {
		return fmt.Errorf("%w: %q", errMissedRequiredParam, "repository")
	}

	if branch == "" {
		return fmt.Errorf("%w: %q", errMissedRequiredParam, "branch")
	}

	return nil
}

func vendorsFileChanged(changedFiles []string) bool {
	for _, file := range changedFiles {
		if file == vendorsFile {
			return true
		}
	}
	return false
}

func parseVendors(filePath string) ([]Vendor, error) {
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

	return vendors, nil
}

func validateVendors(vendors []Vendor, repoPath string) error {
	resOk := true
	vendorIDs := make(map[string]struct{}, len(vendors))
	urlRegexp := regexp.MustCompile(`^http[s]?://.+$`)

	for _, v := range vendors {
		if !checkRequiredAndNotEmpty("display_name", newNode(v.DisplayName, v.ID)) {
			resOk = false
		}

		if ok := validateVendorWebsite(newNode(v.Website, v.ID), urlRegexp); !ok {
			resOk = false
		}

		ok, err := validateVendorIconURL(newNode(v.IconURL, v.ID), repoPath)
		if err != nil {
			return fmt.Errorf("validate vendor icon: %w", err)
		}

		if !ok {
			resOk = false
		}

		if _, found := vendorIDs[v.ID.Value]; found {
			logVendorWarning(v.ID.Line, v.ID.Column, "not unique vendor id")
			resOk = false
			continue
		}

		vendorIDs[v.ID.Value] = struct{}{}
	}

	if !resOk {
		return errLinterFailed
	}

	return nil
}

func validateVendorWebsite(website Node, regexp *regexp.Regexp) bool {
	if !checkRequiredAndNotEmpty("website", website) {
		return false
	}

	if regexp.FindString(website.Value) != website.Value {
		logVendorWarning(website.Line, website.Column, "invalid URL format")
		return false
	}

	return true
}

func validateVendorIconURL(iconURL Node, repoPath string) (bool, error) {
	if !checkRequiredAndNotEmpty("icon_url", iconURL) {
		return false, nil
	}

	if !strings.HasPrefix(iconURL.Value, iconURLPrefix) {
		logVendorWarning(iconURL.Line, iconURL.Column, "icon_url should start with "+iconURLPrefix)
		return false, nil
	}

	fileURL := strings.Replace(iconURL.Value, "Enapter/marketplace/main", repoPath, 1)

	ok, err := checkResourceExistsAtURL(fileURL)
	if err != nil {
		return false, fmt.Errorf("check vendor icon: %w", err)
	}

	if !ok {
		logVendorWarning(iconURL.Line, iconURL.Column, fmt.Sprintf("file not found at the %s", fileURL))
		return false, nil
	}

	return true, nil
}

func checkRequiredAndNotEmpty(name string, node Node) bool {
	if node.IsZero() {
		logVendorWarning(node.Root.Line, node.Root.Column, fmt.Sprintf("%s is required", name))
		return false
	}

	if node.Value == "" {
		logVendorWarning(node.Line, node.Column, fmt.Sprintf("%s should not be empty", name))
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

func logVendorWarning(line, column int, msg string) {
	var builder strings.Builder

	builder.WriteString(vendorsFile)
	if line != 0 {
		builder.WriteString(fmt.Sprintf(":%d", line))
	}
	builder.WriteString(": " + msg)

	fmt.Fprintf(os.Stdout, "::warning file=%s,line=%d,col=%d::%s\n", vendorsFile, line, column, builder.String())
}
