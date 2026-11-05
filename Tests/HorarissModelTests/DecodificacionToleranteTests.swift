import Testing
import Foundation
@testable import HorarissModel

// La decodificación tolerante es lo único de este módulo que, si se rompe, borra
// datos de usuarios reales en silencio. Por eso es lo primero que se prueba: al
// mover los modelos a un paquete no puede cambiar ni un valor por omisión.
@Suite("Decodificación tolerante")
struct DecodificacionToleranteTests {

    @Test("HorarioDia sin aula sigue decodificando")
    func horarioDiaSinAula() throws {
        let json = #"{"dia":3,"horario":780000000}"#.data(using: .utf8)!
        let b = try JSONDecoder().decode(HorarioDia.self, from: json)
        #expect(b.dia == 3)
        #expect(b.aula == "")
        #expect(b.duracionHoras == 1)
        #expect(b.duracionMinutos == 0)
    }

    @Test("Materia vieja sin icono, curso, aula ni notas")
    func materiaVieja() throws {
        let json = #"{"nombre":"Cálculo","horario":780000000,"colorHex":"88BAE8"}"#
            .data(using: .utf8)!
        let m = try JSONDecoder().decode(Materia.self, from: json)
        #expect(m.nombre == "Cálculo")
        #expect(m.icono == "book.fill")
        #expect(m.curso == 0)
        #expect(m.aula == "")
        #expect(m.notas == "")
        #expect(m.horarios.isEmpty)
    }

    @Test("HoraPersonal vacía cae en los valores neutros del catálogo")
    func horaPersonalVacia() throws {
        let h = try JSONDecoder().decode(HoraPersonal.self, from: "{}".data(using: .utf8)!)
        #expect(h.tipo == .libre)
        #expect(h.colorHex == CatalogoHoras.colorLibrePropia)
        #expect(h.icono == CatalogoHoras.iconoLibrePropia)
    }

    @Test("Usuario vacío no se queda sin nombre ni curso")
    func usuarioVacio() throws {
        let u = try JSONDecoder().decode(Usuario.self, from: "{}".data(using: .utf8)!)
        #expect(u.nombre == "")
        #expect(u.curso == "")
        #expect(u.esPremium == false)
        #expect(u.saludo == .nb)
    }

    @Test("Un bloque derivado del horario global sale cuando horarios está vacío")
    func bloqueDerivado() {
        let m = Materia(nombre: "Física", horario: Date(), colorHex: "EFC3CB",
                        diasSemana: [2, 4], duracionHoras: 2)
        #expect(m.bloques(dia: 2).count == 1)
        #expect(m.bloques(dia: 3).isEmpty)
        #expect(m.bloquesOrdenados.count == 2)
        #expect(m.bloques(dia: 2).first?.duracionMin == 120)
    }

    @Test("El gris de estudio rota sin salirse del arreglo")
    func rotacionDeGrises() {
        let n = CatalogoHoras.grisesEstudio.count
        #expect(CatalogoHoras.grisPara(indice: 0) == CatalogoHoras.grisesEstudio[0].claro)
        #expect(CatalogoHoras.grisPara(indice: n) == CatalogoHoras.grisesEstudio[0].claro)
        #expect(CatalogoHoras.grisPara(indice: -1) == CatalogoHoras.grisesEstudio[1].claro)
    }
}
