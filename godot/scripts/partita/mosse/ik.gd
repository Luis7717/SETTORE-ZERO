# Cinematica inversa a due ossa (coscia-gamba-piede, braccio-avambraccio-mano): porting di twoBone di src/ik.js.
# Conto puro; chi mette le ossa dello scheletro in posa è figura.gd.
# (Godot 4.7 ha anche TwoBoneIK3D: qui si usa questa per avere la stessa posa del web — stessa cerniera, stessi poli.)
extends RefCounted


## A = radice (anca), C = bersaglio (caviglia), a e b = lunghezze delle due ossa, pole = verso cui punta il ginocchio.
## Ritorna {knee, end (il bersaglio o il punto più vicino raggiungibile), hinge (asse di piegatura), reach}.
static func two_bone(A: Vector3, C: Vector3, a: float, b: float, pole: Vector3) -> Dictionary:
	var v := C - A
	var d0 := v.length()
	var u := v / d0 if d0 > 1e-9 else Vector3(0, -1, 0)
	var d := clampf(d0, absf(a - b) + 1e-4, (a + b) * 0.9999)
	var w := pole - u * pole.dot(u)
	if w.length() < 1e-6:
		w = u.cross(Vector3(0, 1, 0)) if absf(u.y) < 0.9 else u.cross(Vector3(1, 0, 0))
	w = w.normalized()
	var ca := clampf((a * a + d * d - b * b) / (2.0 * a * d), -1.0, 1.0)
	var sa := sqrt(1.0 - ca * ca)
	return {"knee": A + u * (a * ca) + w * (a * sa), "end": A + u * d, "hinge": w.cross(u).normalized(),
		"reach": d0 <= (a + b) * 0.9999 + 1e-9}
