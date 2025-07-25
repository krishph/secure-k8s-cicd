package main

import rego.v1

good_container := {
    "name": "backend", "image": "docker.io/securecicd/backend:demo",
    "resources": {"requests": {"cpu": "100m", "memory": "64Mi"}, "limits": {"cpu": "500m", "memory": "128Mi"}},
    "securityContext": {"runAsNonRoot": true, "runAsUser": 10001, "privileged": false, "allowPrivilegeEscalation": false, "readOnlyRootFilesystem": true},
}
good_spec := {"containers": [good_container]}
good_pod := {"kind": "Pod", "metadata": {"name": "test"}, "spec": good_spec}

test_compliant_pod if { count(deny) == 0 with input as good_pod }

test_latest_rejected if {
    bad := json.patch(good_pod, [{"op": "replace", "path": "/spec/containers/0/image", "value": "docker.io/securecicd/backend:latest"}])
    results := deny with input as bad
    some msg in results
    startswith(msg, "SC001")
}

test_digest_allowed if {
    image := "docker.io/securecicd/backend@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    pod := json.patch(good_pod, [{"op": "replace", "path": "/spec/containers/0/image", "value": image}])
    count(deny) == 0 with input as pod
}

test_registry_lookalike_rejected if {
    pod := json.patch(good_pod, [{"op": "replace", "path": "/spec/containers/0/image", "value": "docker.io/securecicd-evil/backend:demo"}])
    results := deny with input as pod
    some msg in results
    startswith(msg, "SC002")
}

test_all_workload_wrappers if {
    every kind in ["Deployment", "StatefulSet", "DaemonSet", "ReplicaSet", "ReplicationController", "Job"] {
        workload := {"kind": kind, "metadata": {"name": "test"}, "spec": {"template": {"spec": good_spec}}}
        count(deny) == 0 with input as workload
        bad_spec := object.union(good_spec, {"hostNetwork": true})
        bad := {"kind": kind, "metadata": {"name": "test"}, "spec": {"template": {"spec": bad_spec}}}
        count(deny) == 1 with input as bad
    }
}

test_cronjob_and_list if {
    spec := object.union(good_spec, {"hostPID": true})
    job := {"kind": "CronJob", "metadata": {"name": "job"}, "spec": {"jobTemplate": {"spec": {"template": {"spec": spec}}}}}
    count(deny) == 1 with input as {"kind": "List", "items": [good_pod, job]}
}

test_init_and_ephemeral_containers if {
    every field in ["initContainers", "ephemeralContainers"] {
        bad := object.union(good_container, {"name": "debug", "image": "docker.io/securecicd/backend:latest"})
        spec := object.union(good_spec, {field: [bad]})
        pod := object.union(good_pod, {"spec": spec})
        results := deny with input as pod
        some msg in results
        startswith(msg, "SC001")
    }
}

test_container_root_overrides_pod_defaults if {
    sc := object.union(good_container.securityContext, {"runAsUser": 0})
    c := object.union(good_container, {"securityContext": sc})
    spec := {"containers": [c], "securityContext": {"runAsNonRoot": true, "runAsUser": 10001}}
    pod := object.union(good_pod, {"spec": spec})
    results := deny with input as pod
    some msg in results
    startswith(msg, "SC006")
}
