local pull = {
  pull: "always"
};

local cacheStep = pull + {
  failure: "ignore",
  image: "plugins/s3-cache"
};

local Build(name, imageSuffix, script, failure, cacheUrl, buildOpts = {}) =
  local cachePath = "icinga2/" + imageSuffix;
  local cacheEnv = {
    PLUGIN_PULL: "true",
    PLUGIN_ENDPOINT: cacheUrl,
    PLUGIN_ACCESS_KEY: {
      from_secret: "minio-access-key"
    },
    PLUGIN_SECRET_KEY: {
      from_secret: "minio-secret-key"
    },
    PLUGIN_ROOT: "cache",
    PLUGIN_PATH: cachePath
  };
  {
    kind: "pipeline",
    name: name,
    image_pull_secrets: [
      "gitlab-docker-registry-credentials"
    ],
    failure: failure,
    steps: [
      cacheStep + {
        name: "restore cache",
        environment: cacheEnv + {
          PLUGIN_RESTORE: "true"
        }
      },
      pull + buildOpts + {
        name: "build",
        image: "registry.icinga.com/build-docker/" + imageSuffix,
        commands: [
          ".drone/" + script + ".sh"
        ]
      },
      cacheStep + {
        name: "save cache",
        environment: cacheEnv + {
          PLUGIN_REBUILD: "true",
          PLUGIN_MOUNT: "ccache"
        }
      },
      cacheStep + {
        name: "cleanup cache",
        environment: cacheEnv + {
          PLUGIN_FLUSH: "true",
          PLUGIN_FLUSH_PATH: cachePath
        }
      }
    ]
  };

local K8s(name, imageSuffix, script, failure = "") =
  Build(name, imageSuffix, script, failure, "http://drone-minio:9000", {
    resources: {
      limits: {
        cpu: 1000,
        memory: "3584MiB"
      }
    }
  }) + {
    type: "kubernetes",
    metadata: {
      namespace: "drone"
    },
    node_selector: {
      "magnum.openstack.org/nodegroup": "build-worker-xxlarge"
    }
  };

local Docker(name, imageSuffix, script, os, failure = "") =
  Build(name, imageSuffix, script, failure, "https://minio.drone.icinga.com") + {
    type: "docker"
  };

local DebArch(distro, codename, bits, imageSuffix) = [
  K8s(distro + " " + codename + " x" + bits, distro + "/" + codename + imageSuffix, "deb")
];

local Deb(distro, codename, has32bit = true) =
  DebArch(distro, codename, 64, "") +
  (if has32bit then DebArch(distro, codename, 32, ":x86") else []);

local RPM(distro, release) = K8s(
  distro + " " + release,
  distro + "/" + release,
  "rpm",
  (if distro == "sles" then "ignore" else "")
);

local RasPi(codename) = Docker("raspbian " + codename, "raspbian/" + codename, "raspi", "linux");

  /*
Deb("debian", "buster") +
Deb("debian", "stretch") +
Deb("ubuntu", "focal", false) +
Deb("ubuntu", "bionic") +
Deb("ubuntu", "xenial") +
  */
[
  RPM("centos", "8"),
  /*
  RPM("centos", "7"),
  RPM("centos", "6"),
  RPM("fedora", "32"),
  RPM("fedora", "31"),
  RPM("fedora", "30"),
  RPM("fedora", "29"),
  RPM("sles", "15.1"),
  RPM("sles", "15.0"),
  RPM("sles", "12.5"),
  RPM("sles", "12.4"),
  RPM("opensuse", "15.1"),
  RPM("opensuse", "15.0"),
  */
  RasPi("buster"),
]
