import 'celestial_body.dart';
import 'orbital_elements.dart';

/// The bodies in the simulation.
///
/// Orbital elements are the Jet Propulsion Laboratory's approximate elements
/// for the major planets, referred to the J2000 ecliptic, with rates per Julian
/// century. They are intended for the interval 1800-2050, where they place the
/// planets to within a few arcminutes.
///
/// Physical data (radii, rotation periods, axial tilts) comes from the NASA
/// planetary fact sheets. Radii are kept in step with the generated models by
/// `test/body_catalog_test.dart`, which checks them against
/// `assets/data/bodies.json`.
class BodyCatalog {
  const BodyCatalog._();

  static const CelestialBody sun = CelestialBody(
    key: 'sun',
    label: 'Sun',
    type: BodyType.star,
    radiusKm: 696340.0,
    rotationHours: 609.12,
    axialTiltDeg: 7.25,
    gravity: 274.0,
    meanTemperatureC: 5505.0,
    description:
        'The Sun holds 99.86% of the mass of the solar system. Its core fuses '
        '600 million tonnes of hydrogen every second, and the light that '
        'reaches you left its surface about eight minutes ago.',
  );

  static const CelestialBody mercury = CelestialBody(
    key: 'mercury',
    label: 'Mercury',
    type: BodyType.terrestrial,
    radiusKm: 2439.7,
    rotationHours: 1407.6,
    axialTiltDeg: 0.034,
    gravity: 3.7,
    meanTemperatureC: 167.0,
    description:
        'The smallest planet and the fastest, rounding the Sun every 88 days. '
        'With almost no atmosphere to hold heat, its surface swings between '
        '430°C in daylight and -180°C at night.',
    elements: OrbitalElements(
      semiMajorAxisAu: 0.38709927,
      eccentricity: 0.20563593,
      inclinationDeg: 7.00497902,
      meanLongitudeDeg: 252.25032350,
      longitudeOfPerihelionDeg: 77.45779628,
      longitudeOfAscendingNodeDeg: 48.33076593,
      semiMajorAxisRate: 0.00000037,
      eccentricityRate: 0.00001906,
      inclinationRate: -0.00594749,
      meanLongitudeRate: 149472.67411175,
      longitudeOfPerihelionRate: 0.16047689,
      longitudeOfAscendingNodeRate: -0.12534081,
    ),
  );

  static const CelestialBody venus = CelestialBody(
    key: 'venus',
    label: 'Venus',
    type: BodyType.terrestrial,
    radiusKm: 6051.8,
    rotationHours: -5832.5,
    axialTiltDeg: 177.36,
    gravity: 8.87,
    meanTemperatureC: 464.0,
    description:
        'Venus turns backwards, and so slowly that its day is longer than its '
        'year. A thick carbon dioxide atmosphere traps heat well enough to melt '
        'lead at the surface.',
    elements: OrbitalElements(
      semiMajorAxisAu: 0.72333566,
      eccentricity: 0.00677672,
      inclinationDeg: 3.39467605,
      meanLongitudeDeg: 181.97909950,
      longitudeOfPerihelionDeg: 131.60246718,
      longitudeOfAscendingNodeDeg: 76.67984255,
      semiMajorAxisRate: 0.00000390,
      eccentricityRate: -0.00004107,
      inclinationRate: -0.00078890,
      meanLongitudeRate: 58517.81538729,
      longitudeOfPerihelionRate: 0.00268329,
      longitudeOfAscendingNodeRate: -0.27769418,
    ),
  );

  static const CelestialBody earth = CelestialBody(
    key: 'earth',
    label: 'Earth',
    type: BodyType.terrestrial,
    radiusKm: 6371.0,
    rotationHours: 23.9345,
    axialTiltDeg: 23.44,
    gravity: 9.807,
    meanTemperatureC: 15.0,
    moonCount: 1,
    description:
        'The only place known to hold liquid water at the surface, and the only '
        'one known to hold life. Its 23.4° tilt is what gives the planet '
        'seasons.',
    elements: OrbitalElements(
      semiMajorAxisAu: 1.00000261,
      eccentricity: 0.01671123,
      inclinationDeg: -0.00001531,
      meanLongitudeDeg: 100.46457166,
      longitudeOfPerihelionDeg: 102.93768193,
      longitudeOfAscendingNodeDeg: 0.0,
      semiMajorAxisRate: 0.00000562,
      eccentricityRate: -0.00004392,
      inclinationRate: -0.01294668,
      meanLongitudeRate: 35999.37244981,
      longitudeOfPerihelionRate: 0.32327364,
      longitudeOfAscendingNodeRate: 0.0,
    ),
  );

  static const CelestialBody moon = CelestialBody(
    key: 'moon',
    label: 'Moon',
    type: BodyType.moon,
    radiusKm: 1737.4,
    rotationHours: 655.72,
    axialTiltDeg: 6.68,
    gravity: 1.62,
    meanTemperatureC: -20.0,
    parentKey: 'earth',
    orbitalPeriodDaysOverride: 27.321582,
    description:
        'Locked in step with Earth, the Moon shows us one face and keeps the '
        'other turned away. It drifts about 3.8 cm further from us each year.',
    // Mean elements relative to Earth. The real lunar orbit is perturbed
    // heavily by the Sun; this reproduces the month and the 5.1° inclination
    // but not the finer wobbles.
    elements: OrbitalElements(
      semiMajorAxisAu: 0.00257,
      eccentricity: 0.0549,
      inclinationDeg: 5.145,
      meanLongitudeDeg: 218.316,
      longitudeOfPerihelionDeg: 83.353,
      longitudeOfAscendingNodeDeg: 125.045,
      meanLongitudeRate: 481267.881,
      longitudeOfPerihelionRate: 4069.0137,
      longitudeOfAscendingNodeRate: -1934.1362,
    ),
  );

  static const CelestialBody mars = CelestialBody(
    key: 'mars',
    label: 'Mars',
    type: BodyType.terrestrial,
    radiusKm: 3389.5,
    rotationHours: 24.6229,
    axialTiltDeg: 25.19,
    gravity: 3.71,
    meanTemperatureC: -65.0,
    moonCount: 2,
    description:
        'Rust in the soil gives Mars its colour. It carries the tallest volcano '
        'in the solar system, Olympus Mons, three times the height of Everest.',
    elements: OrbitalElements(
      semiMajorAxisAu: 1.52371034,
      eccentricity: 0.09339410,
      inclinationDeg: 1.84969142,
      meanLongitudeDeg: -4.55343205,
      longitudeOfPerihelionDeg: -23.94362959,
      longitudeOfAscendingNodeDeg: 49.55953891,
      semiMajorAxisRate: 0.00001847,
      eccentricityRate: 0.00007882,
      inclinationRate: -0.00813131,
      meanLongitudeRate: 19140.30268499,
      longitudeOfPerihelionRate: 0.44441088,
      longitudeOfAscendingNodeRate: -0.29257343,
    ),
  );

  static const CelestialBody jupiter = CelestialBody(
    key: 'jupiter',
    label: 'Jupiter',
    type: BodyType.gasGiant,
    radiusKm: 69911.0,
    rotationHours: 9.9250,
    axialTiltDeg: 3.13,
    gravity: 24.79,
    meanTemperatureC: -110.0,
    moonCount: 95,
    description:
        'Jupiter is more massive than every other planet combined, and spins '
        'once in under ten hours. The Great Red Spot is a storm that has been '
        'turning for at least 150 years.',
    elements: OrbitalElements(
      semiMajorAxisAu: 5.20288700,
      eccentricity: 0.04838624,
      inclinationDeg: 1.30439695,
      meanLongitudeDeg: 34.39644051,
      longitudeOfPerihelionDeg: 14.72847983,
      longitudeOfAscendingNodeDeg: 100.47390909,
      semiMajorAxisRate: -0.00011607,
      eccentricityRate: -0.00013253,
      inclinationRate: -0.00183714,
      meanLongitudeRate: 3034.74612775,
      longitudeOfPerihelionRate: 0.21252668,
      longitudeOfAscendingNodeRate: 0.20469106,
    ),
  );

  static const CelestialBody saturn = CelestialBody(
    key: 'saturn',
    label: 'Saturn',
    type: BodyType.gasGiant,
    radiusKm: 58232.0,
    rotationHours: 10.656,
    axialTiltDeg: 26.73,
    gravity: 10.44,
    meanTemperatureC: -140.0,
    moonCount: 146,
    ringModelAsset: 'assets/models/saturn_rings.glb',
    ringInnerRadii: 1.24,
    ringOuterRadii: 2.27,
    description:
        'Saturn is less dense than water. Its rings span tens of thousands of '
        'kilometres but are only about ten metres thick.',
    elements: OrbitalElements(
      semiMajorAxisAu: 9.53667594,
      eccentricity: 0.05386179,
      inclinationDeg: 2.48599187,
      meanLongitudeDeg: 49.95424423,
      longitudeOfPerihelionDeg: 92.59887831,
      longitudeOfAscendingNodeDeg: 113.66242448,
      semiMajorAxisRate: -0.00125060,
      eccentricityRate: -0.00050991,
      inclinationRate: 0.00193609,
      meanLongitudeRate: 1222.49362201,
      longitudeOfPerihelionRate: -0.41897216,
      longitudeOfAscendingNodeRate: -0.28867794,
    ),
  );

  static const CelestialBody uranus = CelestialBody(
    key: 'uranus',
    label: 'Uranus',
    type: BodyType.iceGiant,
    radiusKm: 25362.0,
    rotationHours: -17.24,
    axialTiltDeg: 97.77,
    gravity: 8.87,
    meanTemperatureC: -195.0,
    moonCount: 28,
    description:
        'Uranus is tipped almost onto its side, so it rolls along its orbit. '
        'Each pole spends 42 years in sunlight, then 42 years in darkness.',
    elements: OrbitalElements(
      semiMajorAxisAu: 19.18916464,
      eccentricity: 0.04725744,
      inclinationDeg: 0.77263783,
      meanLongitudeDeg: 313.23810451,
      longitudeOfPerihelionDeg: 170.95427630,
      longitudeOfAscendingNodeDeg: 74.01692503,
      semiMajorAxisRate: -0.00196176,
      eccentricityRate: -0.00004397,
      inclinationRate: -0.00242939,
      meanLongitudeRate: 428.48202785,
      longitudeOfPerihelionRate: 0.40805281,
      longitudeOfAscendingNodeRate: 0.04240589,
    ),
  );

  static const CelestialBody neptune = CelestialBody(
    key: 'neptune',
    label: 'Neptune',
    type: BodyType.iceGiant,
    radiusKm: 24622.0,
    rotationHours: 16.11,
    axialTiltDeg: 28.32,
    gravity: 11.15,
    meanTemperatureC: -200.0,
    moonCount: 16,
    description:
        'The most distant planet, and the windiest: gusts reach 2,000 km/h. It '
        'was found by mathematics before anyone saw it, predicted from wobbles '
        "in Uranus's orbit.",
    elements: OrbitalElements(
      semiMajorAxisAu: 30.06992276,
      eccentricity: 0.00859048,
      inclinationDeg: 1.77004347,
      meanLongitudeDeg: -55.12002969,
      longitudeOfPerihelionDeg: 44.96476227,
      longitudeOfAscendingNodeDeg: 131.78422574,
      semiMajorAxisRate: 0.00026291,
      eccentricityRate: 0.00005105,
      inclinationRate: 0.00035372,
      meanLongitudeRate: 218.45945325,
      longitudeOfPerihelionRate: -0.32241464,
      longitudeOfAscendingNodeRate: -0.00508664,
    ),
  );

  /// Every body, in order outward from the Sun.
  static const List<CelestialBody> all = <CelestialBody>[
    sun,
    mercury,
    venus,
    earth,
    moon,
    mars,
    jupiter,
    saturn,
    uranus,
    neptune,
  ];

  /// The planets alone, in order outward from the Sun.
  static List<CelestialBody> get planets =>
      all.where((CelestialBody body) => body.orbitsSun).toList();

  static CelestialBody? byKey(String key) {
    for (final CelestialBody body in all) {
      if (body.key == key) {
        return body;
      }
    }
    return null;
  }
}
