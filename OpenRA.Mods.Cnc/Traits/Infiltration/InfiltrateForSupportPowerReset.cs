#region Copyright & License Information
/*
 * Copyright 2007-2020 The OpenRA Developers (see AUTHORS)
 * This file is part of OpenRA, which is free software. It is made
 * available to you under the terms of the GNU General Public License
 * as published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version. For more
 * information, see COPYING.
 */
#endregion

using System.Linq;
using OpenRA.Mods.Common.Traits;
using OpenRA.Primitives;
using OpenRA.Traits;

namespace OpenRA.Mods.Cnc.Traits
{
	class InfiltrateForSupportPowerResetInfo : ITraitInfo
	{
		public readonly BitSet<TargetableType> Types = default(BitSet<TargetableType>);

		public object Create(ActorInitializer init) { return new InfiltrateForSupportPowerReset(this); }
	}

	class InfiltrateForSupportPowerReset : INotifyInfiltrated
	{
		readonly InfiltrateForSupportPowerResetInfo info;

		public InfiltrateForSupportPowerReset(InfiltrateForSupportPowerResetInfo info)
		{
			this.info = info;
		}

		void INotifyInfiltrated.Infiltrated(Actor self, Actor infiltrator, BitSet<TargetableType> types)
		{
			if (!info.Types.Overlaps(types))
				return;

			var manager = self.Owner.PlayerActor.Trait<SupportPowerManager>();
			var powers = manager.GetPowersForActor(self).Where(sp => !sp.Disabled);
			foreach (var power in powers)
				power.ResetTimer();
		}
	}
}
