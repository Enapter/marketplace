package main

import (
  "errors"
  "flag"
  "fmt"
  "net/http"
  "net/url"
  "os"
  "path/filepath"
  "strings"

  "gopkg.in/yaml.v3"
)

const (
  vendorsFile   = ".vendors/vendors.yml"
  iconURLPrefix = "https://raw.githubusercontent.com/Enapter/marketplace/main/.vendors/icons/"
)

var (
  errMissedRequiredParam = errors.New("missed required parameter")
  errLinterFailed        = errors.New("linter failed")
)

type Vendor struct {
  ID      yaml.Node `yaml:"id"`
  IconURL yaml.Node `yaml:"icon_url"`
  Website yaml.Node `yaml:"website"`
}

func main() {
  marketplacePath := flag.String("p", "./", "path to marketplace directory")
  repo := flag.String("r", "", "repository")
  branch := flag.String("b", "", "branch")
  flag.Parse()

  if err := run(*repo, *branch, *marketplacePath, flag.Args()); err != nil {
    if !errors.Is(err, errLinterFailed) {
      fmt.Printf("::error:: failed run marketplace vendors validation %s\n", err)
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

  for _, v := range vendors {
    if ok := validateVendorWebsite(v.Website); !ok {
      resOk = false
    }

    ok, err := validateVendorIconURL(v.IconURL, repoPath)
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

func validateVendorWebsite(website yaml.Node) bool {
  _, err := url.ParseRequestURI(website.Value)
  if err != nil {
    logVendorWarning(website.Line, website.Column, "does not look like url")
    return false
  }
  return true
}

func validateVendorIconURL(iconURL yaml.Node, repoPath string) (bool, error) {
  if !strings.HasPrefix(iconURL.Value, iconURLPrefix) {
    logVendorWarning(iconURL.Line, iconURL.Column, "icon url should start from "+iconURLPrefix)
    return false, nil
  }

  fileURL := strings.Replace(iconURL.Value, "Enapter/marketplace/main", repoPath, 1)

  ok, err := checkResourceExistsAtURL(fileURL)
  if err != nil {
    return false, fmt.Errorf("check vendor icon: %w", err)
  }

  if !ok {
    logVendorWarning(iconURL.Line, iconURL.Column, fmt.Sprintf("file not found at %s", fileURL))
    return false, nil
  }

  return true, nil
}

func checkResourceExistsAtURL(url string) (bool, error) {
  r, err := http.Get(url)
  if err != nil {
    return false, fmt.Errorf("check url: %w", err)
  }
  defer r.Body.Close()

  return r.StatusCode == http.StatusOK, nil
}

func logVendorWarning(line, column int, msg string) {
  fmt.Printf("::warning file=%s,line=%d,col=%d::%s\n", vendorsFile, line, column, msg)
}
