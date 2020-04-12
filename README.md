Reproducibility Check for MojoHaus master HEADs
===================================================

[```reproducible-central```](https://github.com/jvm-repo-rebuild/reproducible-central) gives a summary of artifacts in Central Repository that are reproducible, eventually partially.

This is great to spread the word once reproducibility work has been done for a public release, but
when reproducibility work has not yet been done, it's sad to discover the issue after having done
a release.

For MojoHaus projects, we need to check reproducibility of latest SNAPSHOT/master HEAD to identify issues before releasing.

## Reproducibility Results

<!-- BEGIN GENERATED CONTENT -->
MojoHaus consists in 1 sub-projects:

- **Latest release: on 1 releases, reproducibility status is 0 :heavy_check_mark: + 1 :warning:
   = 0% :heavy_check_mark:**

- **master HEAD SNAPSHOT: on 1 SNAPSHOTs, reproducibility status is 1 :heavy_check_mark: + 0 :warning:
   = 100% :heavy_check_mark:**

sub-projects details:
   
| groupId | artifactId (buildspec, Git)  | latest release | master HEAD SNAPSHOT |
| ------- | ------------------------------ | ----------------- | ----------------- |
| [org.codehaus.mojo](https://repo.maven.apache.org/maven2/org/codehaus/mojo) | [mojo-parent](https://repo.maven.apache.org/maven2/org/codehaus/mojo/mojo-parent) ([spec](https://github.com/mojohaus/reproducible-mojohaus/tree/master/mojo/mojo-parent.buildspec), [Git](https://github.com/mojohaus/mojo-parent.git)) | [50](https://github.com/mojohaus/reproducible-mojohaus/tree/master/mojo/mojo-parent-50.buildinfo): 1 :heavy_check_mark:  1 [:warning:](https://github.com/mojohaus/reproducible-mojohaus/tree/master/mojo/mojo-parent-50.buildinfo.compare) | [51-SNAPSHOT](https://github.com/mojohaus/reproducible-mojohaus/tree/master/mojo/mojo-parent-51-SNAPSHOT.buildinfo): 2 :heavy_check_mark: |
| | **1** | **1: 0 :heavy_check_mark: + 1 :warning: = 0% :heavy_check_mark:: 1 :heavy_check_mark: 1 :warning:** | **1: 1 :heavy_check_mark: + 0 :warning: = 100% :heavy_check_mark:: 2 :heavy_check_mark: 0 :warning:** |
