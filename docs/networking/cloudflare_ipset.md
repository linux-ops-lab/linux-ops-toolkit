# Cloudflare IPSet Maintenance

## Purpose

This document describes the non-automated script used to maintain the `cloudflare4` IP set on `gateway-opensuse-01`.

The purpose of this script is to keep the list of Cloudflare IPv4 source networks up to date so that inbound HTTP and HTTPS traffic forwarded by the gateway is only accepted from Cloudflare and not from arbitrary public source addresses.

This is a deliberate security control in the gateway design.

## Context

The gateway uses `firewalld` with source-based matching through IP sets. One of these IP sets is `cloudflare4`, which contains the public IPv4 ranges used by Cloudflare.

This IP set is referenced by the gateway firewall rules to decide which public requests may be forwarded to the internal reverse proxy.

Without a correct and current `cloudflare4` IP set, two failure modes are possible:

1. Legitimate public traffic from Cloudflare is no longer forwarded correctly.
2. The gateway security model becomes weaker if filtering is bypassed or replaced with broader allow rules.

## Design Goal

The goal is not merely to store Cloudflare IP ranges, but to support the intended traffic model:

- public web traffic should enter through Cloudflare
- the gateway should only trust Cloudflare source ranges for external HTTP and HTTPS forwarding
- the reverse proxy backend should not be exposed directly
- local LAN exceptions should remain separate from public Cloudflare access

In other words, the IP set is part of the access-control model, not just a convenience object.

## Role in the Gateway Rule Logic

On `gateway-opensuse-01`, the firewall is structured so that:

- direct access to the reverse proxy backend on ports 80 and 443 is blocked
- HTTP and HTTPS requests to the gateway are only forwarded when the source belongs to `cloudflare4`
- separate LAN-based exceptions exist for internal clients
- anything not explicitly matched is dropped because the zone target is `DROP`

Because of that, `cloudflare4` is a critical dependency for the public access path.

If the IP set is missing, incomplete, or outdated, public access through Cloudflare can fail even when all backend services are healthy.

## Why a Manual Script Exists

The current script is intentionally not a fully automated service or timer-driven workflow.

It is a long, manually executed maintenance script whose purpose is to refresh the Cloudflare IPv4 network list in a controlled way.

That means the update process depends on manual execution by an administrator. This has both advantages and disadvantages.

### Advantages

- Changes are applied consciously and not silently in the background.
- The administrator can observe warnings and errors during the update.
- The process remains transparent and easy to reason about.
- It avoids introducing additional automation layers before the logic is fully matured.

### Disadvantages

- The process depends on regular manual execution.
- Cloudflare IP range changes are not applied automatically.
- Delayed execution can create unexpected connectivity issues.
- The script may become brittle if it is too static or too tightly coupled to assumptions about the current firewall state.

## Functional Logic of the Script

The script is expected to do the following at a conceptual level:

1. Retrieve the current Cloudflare IPv4 ranges from Cloudflare.
2. Compare or apply these ranges against the local `cloudflare4` IP set.
3. Ensure that the firewall continues to use a current set of trusted Cloudflare source networks.
4. Avoid unintentionally removing or weakening the intended public access restrictions.

Even if the script is operationally simple, its role is security-relevant because it directly influences who is allowed to reach forwarded web services.

## What the Script Does Not Do

This script does not replace the full firewall design.

It does not decide how traffic is forwarded. That logic already exists in the gateway rule set.

It also does not validate application health on the reverse proxy or backend systems. The script only maintains one important prerequisite for the public traffic path.

That means a successful run of the script only proves that the Cloudflare source list has been refreshed. It does not prove that the application stack behind the gateway is healthy.

## Operational Dependency

The public web path depends on several layers working together:

1. DNS must resolve the public service correctly.
2. Traffic must arrive through Cloudflare.
3. The source address must match an entry in `cloudflare4`.
4. The gateway must match the correct forward rule.
5. The reverse proxy must be reachable and healthy.
6. The backend application must respond correctly.

The script only affects step 3 directly, but step 3 is mandatory for the public path to work as designed.

## Typical Failure Pattern if the IP Set Is Outdated

A common failure pattern is that services appear healthy internally, but public access fails.

In that situation:

- the backend service may be running
- the reverse proxy may be reachable internally
- local LAN exceptions may still work
- but public requests through Cloudflare may fail because the gateway no longer recognizes all current Cloudflare source ranges

This can create a misleading error picture where the application looks healthy from the inside but unavailable from the outside.

## Verification After Running the Script

After updating the IP set, validation should focus on both configuration state and actual traffic behavior.

The main questions are:

- Is the `cloudflare4` IP set populated as expected?
- Are the relevant firewall rules still referencing the correct IP set?
- Does public traffic through Cloudflare reach the reverse proxy again?
- Do local LAN exceptions still behave independently of the Cloudflare path?
- Is direct backend access still blocked as intended?

The key point is that success should not only be measured by script output, but by whether the gateway behavior still matches the intended design.

## Operational Risks

Because this is a manually executed and comparatively static script, the main risks are procedural and structural.

### Procedural risks

- The script is not run regularly enough.
- The script is run without post-change validation.
- Warnings are ignored even though they may indicate state drift.

### Structural risks

- The script may assume a specific existing firewall state.
- Repeated execution may produce warnings if entries already exist.
- A partial update could leave the IP set inconsistent if the process is interrupted.
- Changes in Cloudflare's published format or endpoint behavior could break the retrieval logic.

## Security Perspective

The `cloudflare4` IP set is part of a trust boundary.

The gateway treats traffic from these source networks differently from all other public traffic. Because of that, the quality and correctness of this IP set directly affects the external exposure model of the environment.

A stale or broken update process is therefore not just a maintenance issue. It can become either:

- an availability issue, if valid Cloudflare traffic is no longer accepted
- or a security issue, if the filtering model is weakened to compensate

## Recommended Documentation Standard

Whenever the script is changed, the documentation should capture at least:

- where the script is stored
- who is expected to run it
- how often it should be reviewed or executed
- what exact object it updates
- how success is verified
- what the rollback or recovery approach is if the update fails

This is especially important because the script is not yet fully automated and therefore depends on operational discipline.

## Strategic Assessment

The current manual script is acceptable as an intermediate solution as long as:

- its purpose is well documented
- its execution is operationally owned
- validation after execution is part of the process
- the gateway rule design around it remains stable and understood

However, the script should be viewed as a controlled manual maintenance mechanism, not as a fully resilient long-term solution.

The more central public service availability becomes, the more important it will be to reduce manual dependency and improve robustness, idempotence, and observability.

## Summary

The `cloudflare4` IP set is a central component of the gateway's public access model.

The manual maintenance script exists to keep this trust list aligned with Cloudflare's current IPv4 ranges. Its job is simple in appearance, but important in effect: it ensures that the gateway continues to distinguish correctly between trusted Cloudflare traffic, local LAN exceptions, and all other public traffic.

As long as the process remains manual, the main operational requirement is discipline: run it consciously, validate the result, and document changes carefully.
