## WARNING:
##
## Using this requires a modded `Garfield` installation that masks the ROOT `TFrame`
## class.
## In `AvalancheMicroscopic.hh` we need to have the following:
## ```
## #define TFrame TFrameROOT
##
## #include <TH1.h>
##
## #include "GarfieldConstants.hh"
## #include "Sensor.hh"
## #include "ViewDrift.hh"
##
## #undef TFrame
## ```
## Because `ViewDrift` ends up pulling in `TFrame`.
## Potentially in the future if this were to wrap more of Garfield++ other such
## changes might be required.
##
## List of affected headers currently wrapped:
## - `AvalancheMicroscopic.hh`
## - `AvalancheMC.hh`

import std / [strutils, os, math]
import pkg / cppstl

{.push cdecl.}

# Headers
# -----------------------------------------------------------------------
when not defined(cpp):
  {.error: "This library only works on the C++ backend. Please compile with `nim cpp`.".}

const libRootPath* = getEnv("ROOTSYS")
when libRootPath.len == 0:
  {.error: "ROOT installation not found. Did you forget to source the `thisRoot.sh` file in this shell?".}
const libGarfieldPath* = getEnv("GARFIELD_INSTALL")
when libGarfieldPath.len == 0:
  {.error: "Garfield installation not found. Did you forget to source the `setupGarfield.sh` file in this shell?".}
const librariesPath* = libGarfieldPath / "lib64"
const headersPath* = libGarfieldPath / "include"

{.passC: gorge("root-config --cflags").}

{.passC: "-I" & headersPath.}
{.passL: "-lGarfield".}
{.passL: "-L" & librariesPath.}

{.passL: gorge("root-config --libs").}


## ##############################
## MediumMagboltz
## ##############################

type
  Medium* {.pure, inheritable, header: "Garfield/Medium.hh", importcpp: "Garfield::Medium".} = object
  MediumGas* {.pure, header: "Garfield/MediumGas.hh", importcpp: "Garfield::MediumGas".} = object of Medium
  MediumMagboltzObj* {.pure, header: "Garfield/MediumMagboltz.hh", importcpp: "Garfield::MediumMagboltz".} = object of MediumGas
  MediumMagboltz* = CppUniquePtr[MediumMagboltzObj]

#proc init*(T: type MediumMagboltz): MediumMagboltz {.constructor, importcpp: "Garfield::MediumMagboltz()".}
#proc init*(T: type MediumMagboltz,
#           gas1: CppString, f1: float,
#           gas2: CppString, f2: float,
#           gas3: CppString, f3: float,
#           gas4: CppString, f4: float,
#           gas5: CppString, f5: float,
#           gas6: CppString, f6: float) {.importcpp: "Garfield::MediumMagboltz(@)".}
#
#proc init*(T: type MediumMagboltz,
#           gas1: string = "", f1: float = 0.0,
#           gas2: string = "", f2: float = 0.0,
#           gas3: string = "", f3: float = 0.0,
#           gas4: string = "", f4: float = 0.0,
#           gas5: string = "", f5: float = 0.0,
#           gas6: string = "", f6: float = 0.0): MediumMagboltz =
#  #var mgas = get(gas)[]
#  MediumMagboltz.init(gas1.toCppString(), f1,
#                      gas2.toCppString(), f2,
#                      gas3.toCppString(), f3,
#                      gas4.toCppString(), f4,
#                      gas5.toCppString(), f5,
#                      gas6.toCppString(), f6)

#proc `=copy`*(dst: var MediumMagboltz, src: MediumMagboltz) {.error: "A MediumMagboltz cannot be copied".}
#proc `=sink`*(dst: var MediumMagboltz, src: MediumMagboltz){.importcpp: "# = std::move(#)".}
#proc `=destroy`*(dst: var MediumMagboltz) {.importcpp: "~MediumMagboltz()".}

#proc `=destroy`*(dst: var MediumMagboltzObj) {.importcpp: "~MediumMagboltz()".}

proc new*(T: type MediumMagboltz): T =
  result = makeUnique(MediumMagboltzObj)

converter toVal*(gas: MediumMagboltz): MediumMagboltzObj = gas.deref()

proc setComposition*(gas: var MediumMagboltzObj,
                     gas1: CppString, f1: float,
                     gas2: CppString, f2: float,
                     gas3: CppString, f3: float,
                     gas4: CppString, f4: float,
                     gas5: CppString, f5: float,
                     gas6: CppString, f6: float) {.importcpp: "#.SetComposition(@)".}

proc setComposition*(gas: var MediumMagboltzObj,
                     gas1: string = "", f1: float = 0.0,
                     gas2: string = "", f2: float = 0.0,
                     gas3: string = "", f3: float = 0.0,
                     gas4: string = "", f4: float = 0.0,
                     gas5: string = "", f5: float = 0.0,
                     gas6: string = "", f6: float = 0.0) =
  gas.setComposition(gas1.toCppString(), f1,
                     gas2.toCppString(), f2,
                     gas3.toCppString(), f3,
                     gas4.toCppString(), f4,
                     gas5.toCppString(), f5,
                     gas6.toCppString(), f6)

proc setTemperature*(gas: var MediumMagboltzObj, temp: float) {.importcpp: "#.SetTemperature(@)".}
proc setPressure*(gas: var MediumMagboltzObj, p: float) {.importcpp: "#.SetPressure(@)".}
proc initialise*(gas: var MediumMagboltzObj, init: bool) {.importcpp: "#.Initialise(@)".}

proc setFieldGrid*(gas: var MediumMagboltzObj, eMin, eMax: float, nE: csize_t, useLog: bool,
                   bMin = 0.0, bMax = 0.0, nb: csize_t = 1, aMin = PI / 2.0, aMax = PI / 2.0,
                   na: csize_t = 1) {.importcpp: "#.SetFieldGrid(@)".}
proc setFieldGrid*(gas: var MediumMagboltzObj, eMin, eMax: float, nE: int, useLog: bool,
                   bMin = 0.0, bMax = 0.0, nb = 1, aMin = PI / 2.0, aMax = PI / 2.0,
                   na = 1) =
  gas.setFieldGrid(eMin, eMax, nE.csize_t, useLog,
                   bMin, bMax, nb.csize_t,
                   aMin, aMax, na.csize_t)
proc writeGasFile*(gas: var MediumMagboltzObj, name: CppString) {.importcpp: "#.WriteGasFile(@)".}
proc writeGasFile*(gas: var MediumMagboltzObj, name: string) =
  gas.writeGasFile(toCppString(name))
proc generateGasTable*(gas: var MediumMagboltzObj,
                       numCollisions: cint = 10,
                       verbose = true) {.importcpp: "#.GenerateGasTable(@)".}
proc generateGasTable*(gas: var MediumMagboltzObj,
                       numCollisions: int = 10,
                       verbose = true) =
  doAssert numCollisions < cint.high, "numCollisions is too large, exceeding the size of cint!"
  gas.generateGasTable(numCollisions.cint, verbose)

#    ok = medium->ElectronVelocity(e[0], e[1], e[2], b[0], b[1], b[2],
#                                  v[0], v[1], v[2]);

proc electronVelocity*(g: var Medium, e0, e1, e2, b0, b1, b2: float,
                       v0, v1, v2: out float): cint {.importcpp: "#.ElectronVelocity(@)".}


## ##############################
## SolidTube
## ##############################

type
  Solid* {.pure, inheritable, header: "Garfield/Solid.hh", importcpp: "Garfield::Solid".} = object
  SolidTube* {.pure, header: "Garfield/SolidTube.hh", importcpp: "Garfield::SolidTube".} = object of Solid

proc init*(T: type SolidTube, cx, cy, cz, r, lz: float): SolidTube {.constructor, importcpp: "Garfield::SolidTube(@)".}

## ##############################
## GeometrySimple
## ##############################

type
  Geometry* {.pure, inheritable, header: "Garfield/Geometry.hh", importcpp: "Garfield::Geometry".} = object
  GeometrySimple* {.pure, header: "Garfield/GeometrySimple.hh", importcpp: "Garfield::GeometrySimple".} = object of Geometry

proc init*(T: type GeometrySimple): GeometrySimple {.constructor, importcpp: "Garfield::GeometrySimple()".}

proc addSolid*(g: var GeometrySimple, s: ptr Solid, m: ptr Medium) {.importcpp: "#.AddSolid(@)".}


## ##############################
## ComponentConstant
## ##############################

type
  Component* {.pure, inheritable, header: "Garfield/Component.hh", importcpp: "Garfield::Component".} = object
  ComponentConstant* {.pure, header: "Garfield/ComponentConstant.hh", importcpp: "Garfield::ComponentConstant".} = object of Component

proc init*(T: type ComponentConstant): ComponentConstant {.constructor, importcpp: "Garfield::ComponentConstant()".}

proc setGeometry*(g: var ComponentConstant, s: ptr Geometry) {.importcpp: "#.SetGeometry(@)".}
proc setElectricField*(g: var ComponentConstant, ex, ey, ez: float) {.importcpp: "#.SetElectricField(@)".}


## ##############################
## Sensor
## ##############################

type
  SensorObj* {.pure, header: "Garfield/Sensor.hh", importcpp: "Garfield::Sensor".} = object
  Sensor* = CppUniquePtr[SensorObj]

#proc init*(T: type Sensor): Sensor {.importcpp: "Garfield::Sensor()".}

## Using `UniquePtr` can lead to problems because it still calls `eqdestroy` in the
## code.
proc new*(T: type Sensor): Sensor =
  result = makeUnique(SensorObj)

#proc `=destroy`*(d: var Sensor) = discard


#converter toVal*(sensor: Sensor): SensorObj = sensor.deref()
#converter toPtr*(sensor: Sensor): ptr SensorObj = sensor.get()

proc addComponent*(g: var SensorObj, s: ptr Component) {.importcpp: "#.AddComponent(@)".}
#proc getComponent*(g: var SensorObj, idx: cuint): ptr Component {.importcpp: "#.GetComponent(@)".}
proc electricField*(g: var SensorObj, x, y, z: float,
                    ex, ey, ez: out float,
                    medium: ptr out Medium, status: out cint) {.importcpp: "#.ElectricField(@)".}



## ##############################
## TrackHeed
## ##############################

type
  Track* {.pure, inheritable, header: "Garfield/Track.hh", importcpp: "Garfield::Track".} = object
  TrackHeed* {.pure, header: "Garfield/TrackHeed.hh", importcpp: "Garfield::TrackHeed".} = object of Track

proc init*(T: type TrackHeed): TrackHeed {.constructor, importcpp: "Garfield::TrackHeed()".}
proc setSensor*(t: var TrackHeed, sensor: ptr SensorObj) {.importcpp: "#.SetSensor(#)".}
proc enableElectricField*(t: var TrackHeed) {.importcpp: "#.EnableElectricField()".}
proc disableElectricField*(t: var TrackHeed) {.importcpp: "#.DisableElectricField()".}

#  void TransportPhoton(const double x0, const double y0, const double z0,
#                       const double t0, const double e0, const double dx0,
#                       const double dy0, const double dz0, int& ne);

proc transportPhoton*(t: var TrackHeed,
                      x0, y0, z0, t0,
                      e0, dx, dy, dz: float,
                      ne: out cint) {.importcpp: "#.TransportPhoton(@)".}
proc transportPhoton*(t: var TrackHeed,
                      x0, y0, z0, t0,
                      e0, dx, dy, dz: float,
                      ne: var int) =
  var tmp: cint
  t.transportPhoton(x0, y0, z0, t0, e0, dx, dy, dz, tmp)
  ne = tmp.int

proc getElectron*(th: var TrackHeed,
                  i: cuint,
                  x, y, z, t, e, dx, dy, dz: out float) {.importcpp: "#.GetElectron(@)".}
proc getElectron*(th: var TrackHeed,
                  i: int,
                  x, y, z, t, e, dx, dy, dz: var float) =
  #th.getElectron(i.cuint, addr x, addr y, addr z, addr t, addr e, addr dx, addr dy, addr dz)
  th.getElectron(i.cuint, x, y, z, t, e, dx, dy, dz)


## ##############################
## AvalancheMicroscopic
## ##############################
import unchained

type
  AvalancheMicroscopic* {.pure, header: "Garfield/AvalancheMicroscopic.hh",
                          importcpp: "Garfield::AvalancheMicroscopic".} = object


proc init*(T: type AvalancheMicroscopic): AvalancheMicroscopic {.constructor, importcpp: "Garfield::AvalancheMicroscopic()".}
proc setSensor*(aval: var AvalancheMicroscopic, sensor: ptr SensorObj) {.importcpp: "#.SetSensor(#)".}
proc avalancheElectron*(aval: var AvalancheMicroscopic,
                        x, y, z, t, e, dx, dy, dz: float) {.importcpp: "#.AvalancheElectron(@)".}

proc getNumberOfElectronEndpointsCpp*(aval: AvalancheMicroscopic): cint {.importcpp: "#.GetNumberOfElectronEndpoints()".}
proc getNumberOfElectronEndpoints*(aval: AvalancheMicroscopic): int =
  result = aval.getNumberOfElectronEndpointsCpp.int


proc getElectronEndpoint*(aval: AvalancheMicroscopic,
                          i: csize_t,
                          x0, y0, z0,  t0,  e0,  x1, y1,  z1,  t1,  e1: out float,
                          status: out cint) {.importcpp: "#.GetElectronEndpoint(@)".}

proc getElectronEndpoint*(aval: AvalancheMicroscopic,
                          i: int,
                          x0, y0, z0, t0, e0, x1, y1, z1, t1, e1: var float,
                          status: var int) =
  #aval.getElectronEndpoint(i.csize_t,
  #                         addr x0, addr y0, addr z0, addr t0, addr e0,
  #                         addr x1, addr y1, addr z1, addr t1, addr e1,
  #                         addr status)
  var tmp: cint
  aval.getElectronEndpoint(i.csize_t,
                           x0, y0, z0, t0, e0,
                           x1, y1, z1, t1, e1,
                           tmp)
  status = tmp.int



## ##############################
## AvalancheMC
## ##############################

type
  AvalancheMC* {.pure, header: "Garfield/AvalancheMC.hh",
                 importcpp: "Garfield::AvalancheMC".} = object

proc init*(T: type AvalancheMC): AvalancheMC {.constructor, importcpp: "Garfield::AvalancheMC()".}
proc setSensor*(aval: var AvalancheMC, sensor: ptr SensorObj) {.importcpp: "#.SetSensor(#)".}
proc avalancheElectron*(aval: var AvalancheMC,
                        x, y, z, t: float, hole = false) {.importcpp: "#.AvalancheElectron(@)".}

proc driftElectron*(aval: var AvalancheMC,
                    x, y, z, t: float) {.importcpp: "#.DriftElectron(@)".}
proc driftHole*(aval: var AvalancheMC,
                x, y, z, t: float) {.importcpp: "#.DriftHole(@)".}

proc setDistanceSteps*(aval: var AvalancheMC, dz: float) {.importcpp: "#.SetDistanceSteps(@)".}
proc setDistanceSteps*[L: Length](aval: var AvalancheMC, dz: L) =
  aval.setDistanceSteps(dz.to(CentiMeter).float)

proc getNumberOfElectronEndpointsCpp*(aval: AvalancheMC): cint {.importcpp: "#.GetNumberOfElectronEndpoints()".}
proc getNumberOfElectronEndpoints*(aval: AvalancheMC): int =
  result = aval.getNumberOfElectronEndpointsCpp.int
proc enableSignalCalculation*(aval: AvalancheMC) {.importcpp: "#.EnableSignalCalculation()".}


proc getElectronEndpoint*(aval: AvalancheMC,
                          i: csize_t,
                          x0, y0, z0, t0,
                          x1, y1, z1, t1: out float,
                          status: out cint) {.importcpp: "#.GetElectronEndpoint(@)".}

proc getElectronEndpoint*(aval: AvalancheMC,
                          i: int,
                          x0, y0, z0, t0, x1, y1, z1, t1: var float,
                          status: var int) =
  #aval.getElectronEndpoint(i.csize_t,
  #                         addr x0, addr y0, addr z0, addr t0, addr e0,
  #                         addr x1, addr y1, addr z1, addr t1, addr e1,
  #                         addr status)
  var tmp: cint
  aval.getElectronEndpoint(i.csize_t,
                           x0, y0, z0, t0,
                           x1, y1, z1, t1,
                           tmp)
  status = tmp.int


{.pop.}

when isMainModule:
  ## Compile with
  ## nim cpp -r garfield.nim
  ## but make sure that you sourced
  ## `libGarfieldPath/share/Garfield/setupGarfield.sh`
  ## before hand and adujst the Garfield path at the top!
  let mb = MediumMagboltz.new()
  mb.setTemperature(293.0)
  mb.setPressure(787.0)
  mb.initialise(true)
