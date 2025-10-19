### Transparent Proxy

```scss
        ┌───────────────────────┐
        │   ProxyAdmin (admin)  │
        │  can upgrade proxy    │
        └──────────┬────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────┐
│ TransparentUpgradeableProxy                      │
│ ┌──────────────────────────────────────────────┐ │
│ │ Storage (balances, owner, etc.)              │ │
│ │ Delegates calls to Implementation            │ │
│ └──────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────┘
                   │
         delegatecall (runtime)
                   ▼
        ┌───────────────────────────┐
        │ Implementation (logic)    │
        │ has initialize(), etc.    │
        └───────────────────────────┘

```
### UpgradebleProxies

```scss
┌──────────────────────────────────────────────────┐
│ UUPSProxy                                        │
│ ┌──────────────────────────────────────────────┐ │
│ │ Storage (balances, etc.)                     │ │
│ │ Delegates calls to Implementation            │ │
│ └──────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────┘
                   │
         delegatecall (runtime)
                   ▼
        ┌───────────────────────────┐
        │ Implementation (logic)    │
        │ has upgradeTo() itself!!  │
        └───────────────────────────┘

```

