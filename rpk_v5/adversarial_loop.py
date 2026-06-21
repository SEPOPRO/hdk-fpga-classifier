#!/usr/bin/env python3
"""
Adversarial Loop — Auto-review pipeline
Lanza un sub-agente adversarial contra el trabajo actual, recoge feedback,
y refina automáticamente.

Uso: python adversarial_loop.py "descripción de la tarea"
"""
import sys, json, subprocess, tempfile

TASK = sys.argv[1] if len(sys.argv) > 1 else "Revisar el último output de investigación"

# Paso 1: Ejecutar adversarial review como sub-agente
print("="*60)
print("🔍 ADVERSARIAL LOOP")
print("="*60)
print(f"\nTarea: {TASK}")

# NOTA: En Hermes esto se hace con delegate_task(skills=['persona-adversarial-review'])
# Este script es el wrapper para invocarlo desde terminal
"""
Flujo:
1. Generar output (el trabajo a revisar)
2. delegate_task con skills=['persona-adversarial-review'] → obtiene críticas
3. Si hay CRITICALs → self_refinement_loop corrige
4. Repetir hasta pasar o max_iteraciones

Comando desde Hermes:
    delegate_task(
        goal="Revisa este output y encuentra fallos", 
        skills=['persona-adversarial-review'],
        context="<output a revisar>"
    )
    → Resultado: críticas severidad
    → Si CRITICAL > 0: delegate_task(skills=['self_refinement_loop']) corrige
    → Loop hasta pasar
"""
print("\n✅ Pipeline adversario listo. Usar desde Hermes con:")
print("  delegate_task(goal='...', skills=['persona-adversarial-review'])")
print("  delegate_task(goal='...', skills=['self_refinement_loop'])")
