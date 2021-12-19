```@meta
CurrentModule = UnixMmap
```
# Public Documentation

## Functions

The following functions are available on all Unix systems.

```@docs
UnixMmap.mmap
UnixMmap.mincore
UnixMmap.madvise!
UnixMmap.msync!
```

OS-specific constants for use with [`mmap`](@ref) and [`madvise!`](@ref) are defined at
(pre)compile time. The following systems are supported based on the available OS
predicates via Julia's `Base.Sys.KERNEL` and `Base.Sys.is*` functions (some of which are
only available for Julia v1.1+).

## Constants — Linux

```@example Linux
import ..LinuxMmap: UnixMmap # hide
import Main._flag_docs # hide
```
```@raw html
<table>
    <thead>
    <tr><td><code>MmapProtection</code></td>
        <td><code>MmapFlags</code></td>
        <td><code>AdviseFlags</code></td>
        <td><code>SyncFlags</code></td>
    </tr>
    </thead>
    <tbody>
        <tr>
            <td>
```
```@example Linux
_flag_docs(UnixMmap.MmapProtection) # hide
```
```@raw html
            </td>
            <td>
```
```@example Linux
_flag_docs(UnixMmap.MmapFlags) # hide
```
```@raw html
            </td>
            <td>
```
```@example Linux
_flag_docs(UnixMmap.AdviseFlags) # hide
```
```@raw html
            </td>
            <td>
```
```@example Linux
_flag_docs(UnixMmap.SyncFlags) # hide
```
```@raw html
            </td>
        </tr>
    </tbody>
</table>
```

## Constants — Apple

```@example Apple
import ..AppleMmap: UnixMmap # hide
import Main._flag_docs # hide
```
```@raw html
<table>
    <thead>
    <tr><td><code>MmapProtection</code></td>
        <td><code>MmapFlags</code></td>
        <td><code>AdviseFlags</code></td>
        <td><code>SyncFlags</code></td>
    </tr>
    </thead>
    <tbody>
        <tr>
            <td>
```
```@example Apple
_flag_docs(UnixMmap.MmapProtection) # hide
```
```@raw html
            </td>
            <td>
```
```@example Apple
_flag_docs(UnixMmap.MmapFlags) # hide
```
```@raw html
            </td>
            <td>
```
```@example Apple
_flag_docs(UnixMmap.AdviseFlags) # hide
```
```@raw html
            </td>
            <td>
```
```@example Linux
_flag_docs(UnixMmap.SyncFlags) # hide
```
```@raw html
            </td>
        </tr>
    </tbody>
</table>
```

## Constants — DragonFly BSD

```@example DragonFly
import ..DragonFlyMmap: UnixMmap # hide
import Main._flag_docs # hide
```
```@raw html
<table>
    <thead>
    <tr><td><code>MmapProtection</code></td>
        <td><code>MmapFlags</code></td>
        <td><code>AdviseFlags</code></td>
        <td><code>SyncFlags</code></td>
    </tr>
    </thead>
    <tbody>
        <tr>
            <td>
```
```@example DragonFly
_flag_docs(UnixMmap.MmapProtection) # hide
```
```@raw html
            </td>
            <td>
```
```@example DragonFly
_flag_docs(UnixMmap.MmapFlags) # hide
```
```@raw html
            </td>
            <td>
```
```@example DragonFly
_flag_docs(UnixMmap.AdviseFlags) # hide
```
```@raw html
            </td>
            <td>
```
```@example Linux
_flag_docs(UnixMmap.SyncFlags) # hide
```
```@raw html
            </td>
        </tr>
    </tbody>
</table>
```

## Constants — FreeBSD

```@example FreeBSD
import ..FreeBSDMmap: UnixMmap # hide
import Main._flag_docs # hide
```
```@raw html
<table>
    <thead>
    <tr><td><code>MmapProtection</code></td>
        <td><code>MmapFlags</code></td>
        <td><code>AdviseFlags</code></td>
        <td><code>SyncFlags</code></td>
    </tr>
    </thead>
    <tbody>
        <tr>
            <td>
```
```@example FreeBSD
_flag_docs(UnixMmap.MmapProtection) # hide
```
```@raw html
            </td>
            <td>
```
```@example FreeBSD
_flag_docs(UnixMmap.MmapFlags) # hide
```
```@raw html
            </td>
            <td>
```
```@example FreeBSD
_flag_docs(UnixMmap.AdviseFlags) # hide
```
```@raw html
            </td>
            <td>
```
```@example Linux
_flag_docs(UnixMmap.SyncFlags) # hide
```
```@raw html
            </td>
        </tr>
    </tbody>
</table>
```

## Constants — NetBSD

```@example NetBSD
import ..NetBSDMmap: UnixMmap # hide
import Main._flag_docs # hide
```
```@raw html
<table>
    <thead>
    <tr><td><code>MmapProtection</code></td>
        <td><code>MmapFlags</code></td>
        <td><code>AdviseFlags</code></td>
        <td><code>SyncFlags</code></td>
    </tr>
    </thead>
    <tbody>
        <tr>
            <td>
```
```@example NetBSD
_flag_docs(UnixMmap.MmapProtection) # hide
```
```@raw html
            </td>
            <td>
```
```@example NetBSD
_flag_docs(UnixMmap.MmapFlags) # hide
```
```@raw html
            </td>
            <td>
```
```@example NetBSD
_flag_docs(UnixMmap.AdviseFlags) # hide
```
```@raw html
            </td>
            <td>
```
```@example Linux
_flag_docs(UnixMmap.SyncFlags) # hide
```
```@raw html
            </td>
        </tr>
    </tbody>
</table>
```

## Constants — OpenBSD

```@example OpenBSD
import ..OpenBSDMmap: UnixMmap # hide
import Main._flag_docs # hide
```
```@raw html
<table>
    <thead>
    <tr><td><code>MmapProtection</code></td>
        <td><code>MmapFlags</code></td>
        <td><code>AdviseFlags</code></td>
        <td><code>SyncFlags</code></td>
    </tr>
    </thead>
    <tbody>
        <tr>
            <td>
```
```@example OpenBSD
_flag_docs(UnixMmap.MmapProtection) # hide
```
```@raw html
            </td>
            <td>
```
```@example OpenBSD
_flag_docs(UnixMmap.MmapFlags) # hide
```
```@raw html
            </td>
            <td>
```
```@example OpenBSD
_flag_docs(UnixMmap.AdviseFlags) # hide
```
```@raw html
            </td>
            <td>
```
```@example Linux
_flag_docs(UnixMmap.SyncFlags) # hide
```
```@raw html
            </td>
        </tr>
    </tbody>
</table>
```

