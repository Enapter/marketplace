package main

import (
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"strings"
	"syscall"
)

var marketplacePath = flag.String("p", "./", "path to marketplace directory")

func main() {
	flag.Parse()

	changed, err := changedBlueprints(*marketplacePath, os.Args[1:])
	if err != nil {
		fmt.Printf("::error::failed to get chnaged blueprints: %s\n", err)
		os.Exit(1)
	}

	paths := make([]string, 0, len(changed))
	for path := range changed {
		paths = append(paths, path)
	}

	fmt.Printf("blueprints-paths=%s", strings.Join(paths, " "))
}

func changedBlueprints(marketplacePath string, changedFiles []string) (map[string]struct{}, error) {
	bpCats, err := blueprintCategories(marketplacePath)
	if err != nil {
		return nil, fmt.Errorf("get current blueprints categories: %w", err)
	}

	changedBps := make(map[string]struct{})
	for _, path := range changedFiles {
		for _, cat := range bpCats {
			if strings.HasPrefix(path, cat) {
				bpPath := strings.Join(strings.Split(path, "/")[:2], "/")
				empty, err := isDirEmptyOrNotExist(bpPath)
				if err != nil {
					return nil, fmt.Errorf("check blueprint dir: %w", err)
				}

				if !empty {
					changedBps[bpPath] = struct{}{}
				}
			}
		}
	}

	return changedBps, nil
}

func blueprintCategories(marketplacePath string) ([]string, error) {
	entries, err := os.ReadDir(marketplacePath)
	if err != nil {
		return nil, fmt.Errorf("open marketplace directory: %w", err)
	}

	cats := make([]string, 0, len(entries))
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		if strings.HasPrefix(entry.Name(), ".") {
			continue
		}

		cats = append(cats, entry.Name())
	}

	return cats, nil
}

func isDirEmptyOrNotExist(name string) (bool, error) {
	f, err := os.Open(name)
	if err != nil {
		if errors.Is(err, syscall.ENOENT) {
			return true, nil
		}
		return false, err
	}
	defer f.Close()

	_, err = f.Readdirnames(1)
	if err != nil {
		if errors.Is(err, io.EOF) {
			return true, nil
		}
		return false, err
	}

	return false, nil
}
