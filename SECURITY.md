# Security Policy

This tool performs local checks for device-visible MDM-related evidence.

It does **not**:

- modify MDM enrollment state
- remove configuration profiles
- bypass Activation Lock
- alter Apple Business Manager / Apple School Manager assignment
- persist scan results by default
- upload scan output, serial numbers, profile contents, or device identifiers to MDM Liberator

During execution, temporary runtime files may be created for endpoint-resolution checks and removed automatically. DNS resolution may occur while checking Apple enrollment-related endpoints; this is network-path evidence only and is not proof of ABM/ADE state.

If you find a security vulnerability, please email security@mdmliberator.com.
