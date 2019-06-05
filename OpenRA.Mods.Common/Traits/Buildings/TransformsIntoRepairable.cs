#region Copyright & License Information
/*
 * Copyright 2007-2019 The OpenRA Developers (see AUTHORS)
 * This file is part of OpenRA, which is free software. It is made
 * available to you under the terms of the GNU General Public License
 * as published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version. For more
 * information, see COPYING.
 */
#endregion

using System;
using System.Collections.Generic;
using System.Linq;
using OpenRA.Activities;
using OpenRA.Mods.Common.Activities;
using OpenRA.Mods.Common.Orders;
using OpenRA.Primitives;
using OpenRA.Traits;

namespace OpenRA.Mods.Common.Traits
{
	[Desc("Add to a building to expose a move cursor that triggers Transforms and issues a repair order to the transformed actor.")]
	public class TransformsIntoRepairableInfo : ConditionalTraitInfo, Requires<TransformsInfo>, Requires<IHealthInfo>
	{
		[ActorReference]
		[FieldLoader.Require]
		public readonly HashSet<string> RepairActors = new HashSet<string> { };

		[VoiceReference]
		public readonly string Voice = "Action";

		public override object Create(ActorInitializer init) { return new TransformsIntoRepairable(this); }
	}

	public class TransformsIntoRepairable : ConditionalTrait<TransformsIntoRepairableInfo>, IIssueOrder, IResolveOrder, IOrderVoice
	{
		Transforms[] transforms;
		IHealth health;

		public TransformsIntoRepairable(TransformsIntoRepairableInfo info)
			: base(info) { }

		protected override void Created(Actor self)
		{
			transforms = self.TraitsImplementing<Transforms>().ToArray();
			health = self.Trait<IHealth>();
			base.Created(self);
		}

		IEnumerable<IOrderTargeter> IIssueOrder.Orders
		{
			get
			{
				if (!IsTraitDisabled)
					yield return new EnterAlliedActorTargeter<BuildingInfo>("Repair", 5, CanRepairAt, _ => CanRepair());
			}
		}

		bool CanRepair()
		{
			return health.DamageState > DamageState.Undamaged && transforms.Any(t => !t.IsTraitDisabled && !t.IsTraitPaused);
		}

		bool CanRepairAt(Actor target)
		{
			return Info.RepairActors.Contains(target.Info.Name);
		}

		Order IIssueOrder.IssueOrder(Actor self, IOrderTargeter order, Target target, bool queued)
		{
			if (order.OrderID == "Repair")
				return new Order(order.OrderID, self, target, queued);

			return null;
		}

		void IResolveOrder.ResolveOrder(Actor self, Order order)
		{
			if (IsTraitDisabled || order.OrderString != "Repair")
				return;

			// Repair orders are only valid for own/allied actors,
			// which are guaranteed to never be frozen.
			if (order.Target.Type != TargetType.Actor)
				return;

			if (!CanRepairAt(order.Target.Actor) || !CanRepair())
				return;

			var currentTransform = self.CurrentActivity as Transform;
			var transform = transforms.FirstOrDefault(t => !t.IsTraitDisabled && !t.IsTraitPaused);
			if (transform == null && currentTransform == null)
				return;

			self.SetTargetLine(order.Target, Color.Green);

			var activity = currentTransform ?? transform.GetTransformActivity(self);
			activity.Queue(self, new IssueOrderAfterTransform(order.OrderString, order.Target));

			if (currentTransform == null)
				self.QueueActivity(order.Queued, activity);
		}

		string IOrderVoice.VoicePhraseForOrder(Actor self, Order order)
		{
			return order.OrderString == "Repair" && !IsTraitDisabled && CanRepair() ? Info.Voice : null;
		}
	}
}
