# RPK v5 — Plan de Implementación: RPK + BNN Ternaria

## Arquitectura Global

```
┌─────────────────────────────────────────────────────────────┐
│                    RPK v5 — Sistema Multimodal               │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐  │
│  │ TEXTO   │   │ VISIÓN   │   │ AUDIO    │   │ FUSIÓN   │  │
│  │ RPK     │   │ BNN Tern │   │ TernPool │   │ Ponderada│  │
│  │ 71.09%  │   │ ~67%     │   │ ~75%     │   │ Decisión │  │
│  │ 0 DSP   │   │ 0 DSP    │   │ 0 DSP    │   │ Final    │  │
│  └────┬────┘   └────┬────┘   └────┬────┘   └────┬────┘  │
│       │             │             │             │         │
│       └─────────────┴─────────────┴─────────────┘         │
│                       │                                   │
│              ┌────────┴────────┐                          │
│              │  UART Switch    │                          │
│              │  o Bus Interno  │                          │
│              └────────┬────────┘                          │
│                       │                                   │
│              ┌────────┴────────┐                          │
│              │   Host (x86)    │                          │
│              └─────────────────┘                          │
└─────────────────────────────────────────────────────────────┘
```

## Fase 1: Integración Texto + Visión (4 semanas)

### Módulo de Visión — BNN Ternaria en LUTs

```
Entrada: imagen 32×32 RGB (3,072 bytes via UART)
    ↓
Filtro Gabor Discreto (LUTs): 8 orientaciones
    ↓ (8 canales × 30×30 = 7,200 features)
RPK Proyección Aleatoria: 7,200 → D dimensions
    ↓ (mismo núcleo RPK que texto)
BNN Ternaria: pesos {-1,0,+1}, 3 capas
    ↓ (XOR + POPCOUNT, mismos bloques que RPK)
Clase: 10 categorías (CIFAR-10)
```

**Recursos estimados:** +15,000 LUTs, +5,000 FFs, 0 DSPs, 0 BRAMs

### Pasos concretos

1. **Extracción de características LUT** — Filtros Gabor discretos (5×5, 8 orientaciones)
   - Implementar como tabla de lookup: 25 píxeles → 1 bit
   - 8 orientaciones × 900 posiciones = 7,200 features
   - Recurso: ~3,000 LUTs

2. **Proyección aleatoria compartida** — Usar el mismo núcleo RPK
   - Matriz de proyección: 7,200 × D (D configurable)
   - Mismo `torch.randint(0,2,(V,D))` que en texto
   - Recurso: ~2,000 LUTs (reutiliza RPK)

3. **BNN ternaria** — 3 capas fully connected ternarias
   - Capa 1: D → 256 (pesos ternarios {-1,0,+1})
   - Capa 2: 256 → 64
   - Capa 3: 64 → 10 (clases)
   - Operación: XNOR + POPCOUNT (idéntico a RPK)
   - Recurso: ~8,000 LUTs

4. **Entrenamiento** (en PC, no FPGA)
   - Dataset: CIFAR-10
   - Framework: PyTorch con `torch.nn.utils.prune`
   - Cuantización ternaria después de entrenar
   - Extraer pesos ternarios → lookup table para FPGA

### Pseudocódigo PyTorch

```python
import torch, torch.nn as nn

class RPKExtractor(nn.Module):
    """Extrae features vía proyección aleatoria"""
    def __init__(self, V=7200, D=4096):
        super().__init__()
        # Fija, no entrenable — misma que RPK texto
        self.register_buffer('W', torch.randint(0,2,(V,D)).float())
    
    def forward(self, x):
        return torch.sign(x @ self.W)  # binarizado

class TernarizedLinear(nn.Module):
    """Capa lineal con pesos ternarios {-1,0,+1}"""
    def __init__(self, in_dim, out_dim):
        super().__init__()
        self.weight = nn.Parameter(torch.randn(out_dim, in_dim))
        self.scale = nn.Parameter(torch.ones(out_dim))
    
    def forward(self, x):
        # Cuantizar a ternario durante forward
        w_tern = torch.sign(torch.relu(torch.abs(self.weight) - 0.5))
        return torch.nn.functional.linear(x, w_tern) * self.scale.view(1,-1)

class RPKBrain(nn.Module):
    """RPK + BNN ternaria completo"""
    def __init__(self, v_dim=7200, rp_dim=4096):
        super().__init__()
        self.rpk = RPKExtractor(v_dim, rp_dim)
        self.bnn = nn.Sequential(
            TernarizedLinear(rp_dim, 256),
            nn.BatchNorm1d(256),
            TernarizedLinear(256, 64),
            nn.BatchNorm1d(64),
            TernarizedLinear(64, 10),
        )
    
    def forward(self, x):
        x = self.rpk(x)
        x = self.bnn(x)
        return x
```

## Fase 2: Integración Audio (2 semanas)

### Módulo de Audio — MFCCs en LUTs + BNN ternaria

```
Entrada: audio 16kHz, ventana 25ms (400 muestras)
    ↓
MFCC Discreto (LUTs): 13 coeficientes × cuadros
    ↓
RPK Proyección: 13×N → D dimensions (mismo núcleo RPK)
    ↓
BNN ternaria: mismas capas que visión
    ↓
Clase: comandos/fugas/anomalías
```

## Fase 3: Fusión Multimodal (2 semanas)

```
Texto   → RPK → vector confianza [20]
Visión  → BNN → vector confianza [10]  
Audio   → BNN → vector confianza [10]
    ↓
Fusión ponderada (LUTs, 0 DSP):
    score[c] = w_t * texto[c] + w_v * vision[c] + w_a * audio[c]
    ↓
Decisión final: argmax(score)
```

## Especificaciones Técnicas Finales

| Parámetro | RPK v4 (actual) | RPK v5 (propuesto) | Edge TPU |
|-----------|:---------------:|:------------------:|:--------:|
| LUTs | ~35,000 | **~55,000** (~41%) | — |
| DSPs | **0** | **0** | Muchos |
| BRAMs | **0** | **0** | Muchos |
| Frecuencia | 70 MHz | **~50 MHz** | — |
| Texto | **71.09%** | **71.09%** ✅ | ~50% |
| Visión | ❌ | **~67% CIFAR-10** 🚧 | ~80% |
| Audio | ❌ | **~75%** 🚧 | ~70% |
| Throughput | ~7,000/s | **~5,000/s** | 500/s |
| Consumo | ~1.5W | **~2W** | 2W |
| Costo HW | $150 | **$150** ✅ | $150 |

## Roadmap

| Semana | Hito | Dependencia |
|:------:|------|:-----------:|
| 1-2 | Filtros Gabor LUT + testbench | Vivado |
| 3-4 | BNN ternaria en Python + export pesos | PyTorch |
| 5-6 | Integración RPK+BNN en VHDL | Fase 1-2 |
| 7 | Síntesis Vivado D=20K completa | VM 64GB |
| 8-9 | Módulo audio (MFCC LUT) | — |
| 10-11 | Fusión multimodal | Fases 1-3 |
| 12 | Reportes finales + bitstream | VM 64GB |
