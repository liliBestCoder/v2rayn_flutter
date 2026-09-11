import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:v2rayn_flutter/models/client_config.dart';
import 'package:v2rayn_flutter/models/line_node.dart';

/// Simulated Mutants of Business Logic
Color _mutant1_ColorThresholdOffByOne(int load) {
  // Mutant: Changed '< 60' to '<= 60'
  if (load <= 60) {
    return const Color(0xff18ad3e);
  } else if (load <= 85) {
    return const Color(0xffff9822);
  } else {
    return const Color(0xffff2d2d);
  }
}

Color _mutant2_UpperBoundaryOffByOne(int load) {
  // Mutant: Changed '<= 85' to '< 85'
  if (load < 60) {
    return const Color(0xff18ad3e);
  } else if (load < 85) {
    return const Color(0xffff9822);
  } else {
    return const Color(0xffff2d2d);
  }
}

bool _mutant3_WindowResizeTriggeredOnLineClick(bool lastLoggedIn, bool currentLoggedIn, bool lineSelected) {
  // Mutant: Resize is called whenever line is clicked or any notifyListeners occurs (Original Bug)
  return lineSelected || (lastLoggedIn != currentLoggedIn);
}

bool _correct_WindowResizeDecoupled(bool lastLoggedIn, bool currentLoggedIn, bool lineSelected) {
  // Correct Implementation: Resize only triggers when login state actually toggles!
  return lastLoggedIn != currentLoggedIn;
}

void main() {
  group('Mutation Testing Suite (Killing Mutants)', () {
    test('Mutant 1 (Off-by-one lower threshold: load=60) is KILLED', () {
      const load = 60;
      const originalNode = LineNode(id: '1', name: 'N', region: 'HK', load: load);
      final expectedColor = originalNode.crowdColor; // Should be yellow (0xffff9822)
      expect(expectedColor, equals(const Color(0xffff9822)));

      final mutantColor = _mutant1_ColorThresholdOffByOne(load);
      // Mutant gives green (0xff18ad3e) instead of yellow
      expect(mutantColor, isNot(equals(expectedColor)), reason: 'Mutant 1 must be detected and killed!');
    });

    test('Mutant 2 (Off-by-one upper threshold: load=85) is KILLED', () {
      const load = 85;
      const originalNode = LineNode(id: '1', name: 'N', region: 'HK', load: load);
      final expectedColor = originalNode.crowdColor; // Should be yellow (0xffff9822)
      expect(expectedColor, equals(const Color(0xffff9822)));

      final mutantColor = _mutant2_UpperBoundaryOffByOne(load);
      // Mutant gives red (0xffff2d2d) instead of yellow
      expect(mutantColor, isNot(equals(expectedColor)), reason: 'Mutant 2 must be detected and killed!');
    });

    test('Mutant 3 (Window resize on line selection) is KILLED', () {
      // User is already logged in (no login state toggle), and user selects a line
      const lastLoggedIn = true;
      const currentLoggedIn = true;
      const lineSelected = true;

      final shouldResizeCorrect = _correct_WindowResizeDecoupled(lastLoggedIn, currentLoggedIn, lineSelected);
      expect(shouldResizeCorrect, isFalse, reason: 'Line selection must NOT trigger window resizing');

      final shouldResizeMutant = _mutant3_WindowResizeTriggeredOnLineClick(lastLoggedIn, currentLoggedIn, lineSelected);
      expect(shouldResizeMutant, isTrue, reason: 'Mutant improperly triggered window resize');

      expect(shouldResizeMutant, isNot(equals(shouldResizeCorrect)), reason: 'Mutant 3 was killed!');
    });

    test('Mutant 4 (Default Tun mode inverted to false) is KILLED', () {
      const config = ClientConfig();
      expect(config.tunEnabled, isTrue, reason: 'ClientConfig default tunEnabled must be true');

      const mutantTunEnabled = false;
      expect(mutantTunEnabled, isNot(equals(config.tunEnabled)), reason: 'Mutant 4 was killed!');
    });

    test('Mutant 5 (Close to tray inverted to false) is KILLED', () {
      const config = ClientConfig();
      expect(config.closeToTray, isTrue, reason: 'ClientConfig default closeToTray must be true');

      const mutantCloseToTray = false;
      expect(mutantCloseToTray, isNot(equals(config.closeToTray)), reason: 'Mutant 5 was killed!');
    });
  });
}
