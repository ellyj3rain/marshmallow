import test from "node:test";
import assert from "node:assert/strict";

import {
  computeNextRootVersion,
  parseRootVersion,
  projectRootVersionToPackageVersion,
} from "../src/core/governance/version.mjs";

test("root VERSION uses the Kohai-aware four-coordinate form", () => {
  const parsed = parseRootVersion("0.1.4.0-alpha");
  assert.equal(parsed.ok, true);
  assert.equal(parsed.major, 0);
  assert.equal(parsed.minor, 1);
  assert.equal(parsed.kohai, 4);
  assert.equal(parsed.patch, 0);
  assert.equal(parsed.maturity, "alpha");
});

test("npm projection preserves the selected prerelease patch coordinate", () => {
  assert.deepEqual(projectRootVersionToPackageVersion("0.1.4.0-alpha"), {
    ok: true,
    version: "0.1.4-alpha",
  });
  assert.deepEqual(projectRootVersionToPackageVersion("0.1.4.1-alpha"), {
    ok: true,
    version: "0.1.4-alpha.patch.1",
  });
  assert.equal(projectRootVersionToPackageVersion("0.1.4.1").ok, false);
  assert.deepEqual(projectRootVersionToPackageVersion("0.1.4.1-alpha", { allowLossyPatchProjection: true }), {
    ok: true,
    version: "0.1.4-alpha",
    lossless: false,
    omittedRootPatch: 1,
  });
});

test("Kohai is the third numeric tier and rolls before minor", () => {
  assert.equal(computeNextRootVersion("0.1.2.0-alpha", "kohai").next, "0.1.3.0-alpha");
  assert.equal(computeNextRootVersion("0.1.16.0-alpha", "kohai").next, "0.2.0.0-alpha");
  assert.equal(computeNextRootVersion("0.1.2.24-alpha", "patch").next, "0.1.3.0-alpha");
});


test("prerelease patch projection is unique across the selected odometer coordinates", () => {
  const seen = new Set();
  for (const maturity of ["pre-alpha", "alpha", "beta", "rc"]) {
    for (let kohai = 0; kohai <= 16; kohai += 1) {
      for (let patch = 0; patch <= 24; patch += 1) {
        const projection = projectRootVersionToPackageVersion(`2.2.${kohai}.${patch}-${maturity}`);
        assert.equal(projection.ok, true);
        assert.equal(seen.has(projection.version), false, projection.version);
        seen.add(projection.version);
        assert.equal(projection.version, `2.2.${kohai}-${maturity}${patch ? `.patch.${patch}` : ""}`);
      }
    }
  }
  assert.equal(computeNextRootVersion("2.2.0.0-alpha", "patch").next, "2.2.0.1-alpha");
  assert.deepEqual(projectRootVersionToPackageVersion("2.2.0.1-alpha"), { ok: true, version: "2.2.0-alpha.patch.1" });
  assert.deepEqual(projectRootVersionToPackageVersion("2.2.1.0-alpha"), { ok: true, version: "2.2.1-alpha" });
});
