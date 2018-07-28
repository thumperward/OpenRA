#region Copyright & License Information
/*
 * Copyright 2007-2018 The OpenRA Developers (see AUTHORS)
 * This file is part of OpenRA, which is free software. It is made
 * available to you under the terms of the GNU General Public License
 * as published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version. For more
 * information, see COPYING.
 */
#endregion

using System.Collections.Generic;
using System.Linq;
using OpenRA.Mods.Common.Effects;
using OpenRA.Primitives;
using OpenRA.Traits;

namespace OpenRA.Mods.Common.Traits
{
	[Desc("Reveal this actor's last position when killed.")]
	public class RevealOnDeathInfo : ConditionalTraitInfo
	{
		[Desc("Stances relative to the actors' owner that shroud will be revealed for.")]
		public readonly Stance RevealForStances = Stance.Ally;

		[Desc("Duration of the reveal.")]
		public readonly int Duration = 25;

		[Desc("Radius of the reveal around this actor.")]
		public readonly WDist Radius = new WDist(1536);

		[Desc("Can this actor be revealed through shroud generated by the GeneratesShroud trait?")]
		public readonly bool RevealGeneratedShroud = true;

		[Desc("DeathTypes for which shroud will be revealed.",
			"Use an empty list (the default) to allow all DeathTypes.")]
		public readonly BitSet<DamageType> DeathTypes = default(BitSet<DamageType>);

		public override object Create(ActorInitializer init) { return new RevealOnDeath(init.Self, this); }
	}

	public class RevealOnDeath : ConditionalTrait<RevealOnDeathInfo>, INotifyKilled
	{
		readonly RevealOnDeathInfo info;

		public RevealOnDeath(Actor self, RevealOnDeathInfo info)
			: base(info)
		{
			this.info = info;
		}

		void INotifyKilled.Killed(Actor self, AttackInfo attack)
		{
			if (IsTraitDisabled)
				return;

			if (!self.IsInWorld)
				return;

			if (!info.DeathTypes.IsEmpty && !attack.Damage.DamageTypes.Overlaps(info.DeathTypes))
				return;

			var owner = self.Owner;
			if (owner != null && owner.WinState == WinState.Undefined)
			{
				self.World.AddFrameEndTask(w =>
				{
					// Actor has been disposed by something else before its death (for example `Enter`).
					if (self.Disposed)
						return;

					w.Add(new RevealShroudEffect(self.CenterPosition, info.Radius,
						info.RevealGeneratedShroud ? Shroud.SourceType.Visibility : Shroud.SourceType.PassiveVisibility,
						owner, info.RevealForStances, duration: info.Duration));
				});
			}
		}
	}
}
