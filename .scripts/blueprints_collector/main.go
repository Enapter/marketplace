package main

import (
	"flag"
	"fmt"
	"os"
	"strings"
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

func changedBlueprints(marketplacePath string, changedFiles []string) (map[string]bool, error) {
	all, err := listBlueprintsWithCategories(marketplacePath)
	if err != nil {
		return nil, err
	}

	changed := make(map[string]bool, len(all))

	for _, file := range changedFiles {
		for _, blueprint := range all {
			if !changed[blueprint] && strings.HasPrefix(file, blueprint) {
				changed[blueprint] = true
				break
			}
		}
	}

	return changed, nil
}

func listBlueprintsWithCategories(marketplacePath string) ([]string, error) {
	categories, err := listNonHiddenDirectories(marketplacePath)
	if err != nil {
		return nil, err
	}

	result := make([]string, 0, len(categories))
	for _, c := range categories {
		blueprints, err := listNonHiddenDirectories(marketplacePath + "/" + c)
		if err != nil {
			return nil, fmt.Errorf("%s: %w", c, err)
		}
		for _, b := range blueprints {
			result = append(result, c+"/"+b)
		}
	}

	return result, nil
}

// listNonHiddenDirectories returns names of non-nidden `path` subdirectories.
//
// Only final components of directory paths are returned, e.g. `bar`, not
// `foo/bar`.
func listNonHiddenDirectories(path string) ([]string, error) {
	entries, err := os.ReadDir(path)
	if err != nil {
		return nil, err
	}

	dirs := make([]string, 0, len(entries))
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		if hidden := strings.HasPrefix(entry.Name(), "."); hidden {
			continue
		}

		dirs = append(dirs, entry.Name())
	}

	return dirs, nil
}
