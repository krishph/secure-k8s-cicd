package main

import rego.v1

# Exact repository matching prevents lookalikes such as securecicd-evil/backend.
# These application names are LOCAL placeholders, not published upstream images.
# Replace them with repositories you own before a registry-backed deployment.
approved_repositories := {
    "docker.io/securecicd/frontend",
    "docker.io/securecicd/backend",
    "docker.io/library/redis",
}

# Walk also handles Kubernetes List objects, without --combine.
workloads contains obj if {
    walk(input, [_, obj])
    is_object(obj)
    obj.kind in {"Pod", "Deployment", "StatefulSet", "DaemonSet", "ReplicaSet", "ReplicationController", "Job", "CronJob"}
}

pod_spec(w) := w.spec if { w.kind == "Pod" }
pod_spec(w) := w.spec.jobTemplate.spec.template.spec if { w.kind == "CronJob" }
pod_spec(w) := w.spec.template.spec if {
    w.kind in {"Deployment", "StatefulSet", "DaemonSet", "ReplicaSet", "ReplicationController", "Job"}
}

containers(spec) := {c |
    some field in ["containers", "initContainers", "ephemeralContainers"]
    c := object.get(spec, field, [])[_]
}

context(w, c) := sprintf("%s/%s container %s", [w.kind, object.get(w.metadata, "name", "unnamed"), object.get(c, "name", "unnamed")])

repository(image) := split(split(image, "@")[0], ":")[0]

# A tag (excluding latest), optionally followed by a digest, or a bare SHA256 digest.
# Qualified repository names are required. Registry ports are intentionally unsupported.
versioned(image) if {
    regex.match(`^[a-z0-9.-]+/[a-z0-9._/-]+:[A-Za-z0-9_][A-Za-z0-9_.-]*(@sha256:[a-f0-9]{64})?$`, image)
    not regex.match(`:latest(@|$)`, image)
}
versioned(image) if {
    regex.match(`^[a-z0-9.-]+/[a-z0-9._/-]+@sha256:[a-f0-9]{64}$`, image)
}

deny contains msg if {
    some w in workloads
    some c in containers(pod_spec(w))
    not versioned(object.get(c, "image", ""))
    msg := sprintf("SC001 %s: use an explicit non-latest tag or sha256 digest", [context(w, c)])
}

deny contains msg if {
    some w in workloads
    some c in containers(pod_spec(w))
    not repository(object.get(c, "image", "")) in approved_repositories
    msg := sprintf("SC002 %s: image repository is not approved", [context(w, c)])
}

nonempty(value) if { is_string(value); value != "" }
nonempty(value) if { is_number(value); value > 0 }

deny contains msg if {
    some w in workloads
    spec := pod_spec(w)
    # Kubernetes does not permit resource declarations on ephemeral containers.
    some field in ["containers", "initContainers"]
    c := object.get(spec, field, [])[_]
    some group in ["requests", "limits"]
    some resource in ["cpu", "memory"]
    values := object.get(object.get(c, "resources", {}), group, {})
    not nonempty(object.get(values, resource, null))
    msg := sprintf("SC003 %s: missing resources.%s.%s", [context(w, c), group, resource])
}

deny contains msg if {
    some w in workloads
    some c in containers(pod_spec(w))
    object.get(object.get(c, "securityContext", {}), "privileged", false) != false
    msg := sprintf("SC004 %s: privileged containers are prohibited", [context(w, c)])
}

deny contains msg if {
    some w in workloads
    some c in containers(pod_spec(w))
    object.get(object.get(c, "securityContext", {}), "allowPrivilegeEscalation", null) != false
    msg := sprintf("SC005 %s: set allowPrivilegeEscalation to false", [context(w, c)])
}

nonroot(spec, c) if {
    pod := object.get(spec, "securityContext", {})
    sc := object.get(c, "securityContext", {})
    object.get(sc, "runAsNonRoot", object.get(pod, "runAsNonRoot", false)) == true
    object.get(sc, "runAsUser", object.get(pod, "runAsUser", -1)) != 0
}

deny contains msg if {
    some w in workloads
    spec := pod_spec(w)
    some c in containers(spec)
    not nonroot(spec, c)
    msg := sprintf("SC006 %s: require runAsNonRoot and prohibit UID 0", [context(w, c)])
}

deny contains msg if {
    some w in workloads
    spec := pod_spec(w)
    some field in ["hostNetwork", "hostPID", "hostIPC"]
    object.get(spec, field, false) != false
    msg := sprintf("SC007 %s/%s: %s is prohibited", [w.kind, w.metadata.name, field])
}

deny contains msg if {
    some w in workloads
    some c in containers(pod_spec(w))
    object.get(object.get(c, "securityContext", {}), "readOnlyRootFilesystem", false) != true
    msg := sprintf("SC008 %s: set readOnlyRootFilesystem to true", [context(w, c)])
}
